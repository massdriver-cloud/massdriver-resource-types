Mix.install([
  {:ex_json_schema, "0.11.1"},
  {:solid, "0.12.0"},
  {:yaml_elixir, "2.11.0"},
  {:jason, "1.4.4"}
])

defmodule Check do
  @root Path.expand("..", __DIR__)
  @icon_base "https://raw.githubusercontent.com/massdriver-cloud/massdriver-resource-types/main"
  @semver ~r/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/

  def run([metaschema_path, render_dir]) do
    metaschema =
      metaschema_path |> File.read!() |> Jason.decode!() |> ExJsonSchema.Schema.resolve()

    errors =
      @root
      |> File.ls!()
      |> Enum.sort()
      |> Enum.filter(&File.exists?(Path.join([@root, &1, "massdriver.yaml"])))
      |> Enum.flat_map(fn type ->
        errors = check_type(type, metaschema, render_dir)
        IO.puts(if errors == [], do: "ok    #{type}", else: "FAIL  #{type}")
        Enum.map(errors, &"#{type}: #{&1}")
      end)

    case errors do
      [] ->
        :ok

      errors ->
        Enum.each(errors, &IO.puts(:stderr, &1))
        System.halt(1)
    end
  end

  def run(_args) do
    IO.puts(:stderr, "usage: elixir scripts/validate.exs <resource-type.json> <render-dir>")
    System.halt(2)
  end

  defp check_type(type, metaschema, render_dir) do
    dir = Path.join(@root, type)
    yaml = YamlElixir.read_from_file!(Path.join(dir, "massdriver.yaml"))
    schema = yaml["schema"] || %{}

    file_errors = metadata_errors(type, dir, yaml) ++ missing_file_errors(dir, yaml)

    if file_errors == [] do
      document = Map.put(schema, "$md", md_block(yaml, dir))

      metaschema_errors(metaschema, document) ++
        schema_errors(schema) ++
        style_errors(schema, "schema") ++
        sensitive_errors(schema) ++
        example_errors(schema, "schema") ++
        export_errors(type, yaml, dir, schema, render_dir)
    else
      file_errors
    end
  end

  defp metadata_errors(type, dir, yaml) do
    [
      {yaml["name"] == type, "name must be #{type}"},
      {is_binary(yaml["version"]) and yaml["version"] =~ @semver,
       "version must be a semantic version"},
      {is_binary(yaml["label"]), "label is required"},
      {yaml["icon"] == "#{@icon_base}/#{type}/icon.svg",
       "icon must be #{@icon_base}/#{type}/icon.svg"},
      {File.exists?(Path.join(dir, "icon.svg")), "icon.svg is missing"},
      {get_in(yaml, ["ui", "connectionOrientation"]) == "link",
       "ui.connectionOrientation must be link"},
      {is_map(yaml["schema"]), "schema is required"}
    ]
    |> Enum.reject(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp referenced_files(yaml) do
    instructions = for i <- get_in(yaml, ["ui", "instructions"]) || [], do: i["path"]
    exports = for e <- yaml["exports"] || [], do: e["templatePath"]
    instructions ++ exports
  end

  defp missing_file_errors(dir, yaml) do
    for path <- referenced_files(yaml),
        not File.regular?(Path.join(dir, path)),
        do: "#{path} does not exist"
  end

  # The stored document that the registry builds from massdriver.yaml (Massdriver.Registry.ResourceTypeYaml).
  defp md_block(yaml, dir) do
    ui =
      yaml["ui"]
      |> Map.take(["connectionOrientation", "environmentDefaultGroup", "schema"])
      |> Map.put(
        "instructions",
        for(
          i <- yaml["ui"]["instructions"] || [],
          do: %{"label" => i["label"], "content" => read(dir, i["path"])}
        )
      )

    export =
      for e <- yaml["exports"] || [] do
        e
        |> Map.take(["downloadButtonText", "fileFormat", "templateLang"])
        |> Map.put("template", read(dir, e["templatePath"]))
      end

    yaml
    |> Map.take(["name", "label", "icon"])
    |> Map.put("ui", ui)
    |> Map.put("export", export)
  end

  defp read(dir, path), do: File.read!(Path.join(dir, path))

  defp metaschema_errors(metaschema, document) do
    case ExJsonSchema.Validator.validate(metaschema, document) do
      :ok -> []
      {:error, errors} -> for {message, path} <- errors, do: "metaschema #{path}: #{message}"
    end
  end

  defp schema_errors(schema) do
    ExJsonSchema.Schema.resolve(schema)
    []
  rescue
    e -> ["schema does not resolve: #{Exception.message(e)}"]
  end

  defp style_errors(%{} = schema, path) do
    own =
      [
        {Map.has_key?(schema, "properties") and schema["additionalProperties"] != false,
         "#{path} must set additionalProperties: false"},
        {path == "schema" and
           not Enum.all?(~w(title description examples required), &Map.has_key?(schema, &1)),
         "schema must have title, description, examples, and required"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    property_errors =
      for {name, property} <- schema["properties"] || %{},
          error <-
            Enum.reject(
              [
                is_binary(property["title"]) || "#{path}.#{name} needs a title",
                is_binary(property["description"]) || "#{path}.#{name} needs a description"
              ],
              &(&1 == true)
            ) ++
              style_errors(property, "#{path}.#{name}"),
          do: error

    item_errors =
      if is_map(schema["items"]), do: style_errors(schema["items"], "#{path}[]"), else: []

    own ++ property_errors ++ item_errors
  end

  defp style_errors(_schema, _path), do: []

  # Massdriver masks a `$md.sensitive` field only when it reaches it through `properties` of objects that
  # declare `type: object` and `items` of arrays that declare `type: array` (Massdriver.Platform.mask_by_schema/2).
  defp sensitive_errors(schema) do
    all = sensitive_paths(schema, "schema", :all)
    masked = sensitive_paths(schema, "schema", :masked)

    for path <- all -- masked,
        do: "#{path} is marked $md.sensitive in a place that Massdriver does not mask"
  end

  defp sensitive_paths(%{} = schema, path, mode) do
    own = if schema["$md.sensitive"] == true, do: [path], else: []

    children =
      for {key, child} <- schema, is_map(child) or is_list(child), into: [] do
        {key, child}
      end

    own ++
      Enum.flat_map(children, fn
        {"properties", props} when is_map(props) ->
          if mode == :all or schema["type"] == "object" or path == "schema" do
            Enum.flat_map(props, fn {name, prop} ->
              sensitive_paths(prop, "#{path}.#{name}", mode)
            end)
          else
            []
          end

        {"items", items} when is_map(items) ->
          if mode == :all or (schema["type"] == "array" and items["type"] == "object") do
            sensitive_paths(items, "#{path}[]", mode)
          else
            []
          end

        {key, value} when mode == :all and is_map(value) ->
          sensitive_paths(value, "#{path}.#{key}", mode)

        {key, value} when mode == :all and is_list(value) ->
          value
          |> Enum.with_index()
          |> Enum.flat_map(fn {v, i} -> sensitive_paths(v, "#{path}.#{key}[#{i}]", mode) end)

        _ ->
          []
      end)
  end

  defp sensitive_paths(_schema, _path, _mode), do: []

  defp example_errors(%{} = schema, path) do
    own =
      case schema["examples"] do
        examples when is_list(examples) ->
          resolved = schema |> Map.delete("examples") |> ExJsonSchema.Schema.resolve()

          for {example, index} <- Enum.with_index(examples),
              {message, at} <- validation_errors(resolved, example),
              do: "#{path}.examples[#{index}] #{at}: #{message}"

        _ ->
          []
      end

    nested =
      Enum.flat_map(schema["properties"] || %{}, fn {name, prop} ->
        example_errors(prop, "#{path}.#{name}")
      end) ++
        if(is_map(schema["items"]), do: example_errors(schema["items"], "#{path}[]"), else: [])

    own ++ nested
  end

  defp example_errors(_schema, _path), do: []

  defp validation_errors(resolved, document) do
    case ExJsonSchema.Validator.validate(resolved, document) do
      :ok -> []
      {:error, errors} -> errors
    end
  end

  defp export_errors(type, yaml, dir, schema, render_dir) do
    for export <- yaml["exports"] || [],
        {example, index} <- Enum.with_index(schema["examples"] || []),
        error <- render_export(type, export, dir, example, index, render_dir),
        do: error
  end

  defp render_export(type, export, dir, example, index, render_dir) do
    file_name = export["templatePath"] |> Path.basename() |> String.replace_suffix(".liquid", "")
    out = Path.join([render_dir, type, Integer.to_string(index), file_name])
    context = %{"artifact" => %{"id" => "#{type}-example-#{index}", "payload" => example}}

    case Solid.parse(read(dir, export["templatePath"])) do
      {:ok, template} ->
        rendered = template |> Solid.render(context) |> IO.iodata_to_binary()
        File.mkdir_p!(Path.dirname(out))
        File.write!(out, rendered)
        IO.puts("      rendered #{Path.relative_to_cwd(out)}")
        rendered_errors(export["fileFormat"], rendered, export["templatePath"])

      {:error, error} ->
        ["#{export["templatePath"]} does not parse: #{inspect(error)}"]
    end
  end

  defp rendered_errors(_format, rendered, path) when rendered == "",
    do: ["#{path} rendered nothing"]

  defp rendered_errors("yaml", rendered, path) do
    case YamlElixir.read_from_string(rendered) do
      {:ok, %{}} -> []
      other -> ["#{path} did not render a YAML map: #{inspect(other)}"]
    end
  end

  defp rendered_errors("conf", rendered, path) do
    for line <- String.split(rendered, "\n"),
        line != "",
        not (line =~ ~r/^\[[A-Za-z]+\]$/ or line =~ ~r/^[A-Za-z]+ = \S.*$/),
        do:
          "#{path} rendered a line that is not a section or a key = value pair: #{inspect(line)}"
  end

  defp rendered_errors(_format, _rendered, _path), do: []
end

Check.run(System.argv())
