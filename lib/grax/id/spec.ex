defmodule Grax.Id.Spec do
  @moduledoc """
  A DSL for the specification of identifier schemas for `Grax.Schema`s.
  """

  alias Grax.Id.Namespace

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :namespaces, accumulate: true)
      Module.register_attribute(__MODULE__, :id_schemas, accumulate: true)
      Module.register_attribute(__MODULE__, :custom_id_schema_selectors, accumulate: true)
      @base_namespace nil
      @parent_namespace nil
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def namespaces, do: @namespaces
      def base_namespace, do: @base_namespace

      if @base_namespace do
        def base_iri, do: RDF.iri(@base_namespace.uri)
      else
        def base_iri, do: nil
      end

      def id_schemas, do: @id_schemas
      def custom_id_schema_selectors, do: @custom_id_schema_selectors

      @prefix_map @namespaces
                  |> Enum.reject(&is_nil(&1.prefix))
                  |> Map.new(&{&1.prefix, Namespace.uri(&1)})
                  |> RDF.PrefixMap.new()
      def prefix_map, do: @prefix_map
    end
  end

  defmacro namespace(segment, opts, do_block)

  defmacro namespace(segment, opts, do: block) do
    {segment, absolute?} =
      case segment do
        {:__aliases__, _, _} = vocab_namespace ->
          {vocab_namespace
           |> Macro.expand(__CALLER__)
           |> apply(:__base_iri__, []), true}

        segment when is_binary(segment) ->
          {segment, nil}

        invalid ->
          raise "invalid namespace: #{inspect(invalid)}"
      end

    quote do
      if @parent_namespace && unquote(absolute?) do
        raise ArgumentError, "absolute URIs are only allowed on the top-level namespace"
      end

      previous_parent_namespace = @parent_namespace

      namespace =
        Namespace.new(
          previous_parent_namespace,
          unquote(segment),
          unquote(opts)
        )

      @namespaces namespace
      @parent_namespace namespace

      unquote(block)

      @parent_namespace previous_parent_namespace
    end
  end

  defmacro namespace(segment, do: block) do
    quote do
      namespace(unquote(segment), [], do: unquote(block))
    end
  end

  defmacro namespace(segment, opts) do
    quote do
      namespace(unquote(segment), unquote(opts), do: nil)
    end
  end

  defmacro base(segment, opts, do_block)

  defmacro base(segment, opts, do: block) do
    quote do
      if @base_namespace do
        raise "already a base namespace defined: #{Namespace.uri(@base_namespace)}"
      end

      namespace(unquote(segment), unquote(opts), do: unquote(block))
      @base_namespace List.first(@namespaces)
    end
  end

  defmacro base(segment, do: block) do
    quote do
      base(unquote(segment), [], do: unquote(block))
    end
  end

  defmacro base(segment, opts) do
    quote do
      base(unquote(segment), unquote(opts), do: nil)
    end
  end

  defmacro id_schema(template, opts) do
    opts =
      case Keyword.get(opts, :var_proc) do
        nil -> opts
        name when is_atom(name) -> Keyword.put(opts, :var_proc, {__CALLER__.module, name})
        _ -> opts
      end

    {opts, custom_selector} =
      case Keyword.get(opts, :selector) do
        nil ->
          {opts, nil}

        name when is_atom(name) ->
          custom_selector = {__CALLER__.module, name}
          {Keyword.put(opts, :selector, custom_selector), custom_selector}

        custom_selector ->
          {opts, custom_selector}
      end

    quote do
      if Enum.find(@custom_id_schema_selectors, fn {existing, _} ->
           existing == unquote(custom_selector)
         end) do
        raise ArgumentError,
              "custom selector #{inspect(unquote(custom_selector))} is already used for another id schema"
      end

      id_schema = Grax.Id.Schema.new(@parent_namespace, unquote(template), unquote(opts))
      @id_schemas id_schema
      if unquote(custom_selector) do
        @custom_id_schema_selectors {unquote(custom_selector), id_schema}
      end
    end
  end

  defmacro id(schema, template, opts \\ []) do
    opts = Keyword.put(opts, :schema, schema)

    quote do
      id_schema unquote(template), unquote(opts)
    end
  end

  def determine_id_schema(spec, schema) do
    Enum.find(spec.id_schemas, fn
      %{schema: ^schema} -> true
      %{schema: schemas} when is_list(schemas) -> schema in schemas
      _ -> false
    end)
    |> case do
      nil -> nil
      id_schema -> %{id_schema | schema: schema}
    end
  end

  def custom_select_id_schema(spec, schema, attributes) do
    Enum.find_value(spec.custom_id_schema_selectors, fn {{mod, fun}, id_schema} ->
      apply(mod, fun, [schema, attributes]) && %{id_schema | schema: schema}
    end)
  end
end
