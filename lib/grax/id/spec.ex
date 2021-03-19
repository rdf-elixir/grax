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
      @parent_namespace nil
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def namespaces, do: @namespaces

      @prefix_map @namespaces
                  |> Enum.reject(&is_nil(&1.prefix))
                  |> Map.new(&{&1.prefix, Namespace.uri(&1)})
                  |> RDF.PrefixMap.new()
      def prefix_map, do: @prefix_map
    end
  end

  defmacro namespace(segment, opts, do_block)

  defmacro namespace(segment, opts, do: block) do
    segment =
      case segment do
        {:__aliases__, _, _} = vocab_namespace ->
          vocab_namespace
          |> Macro.expand(__CALLER__)
          |> apply(:__base_iri__, [])

        segment when is_binary(segment) ->
          segment

        invalid ->
          raise "invalid namespace: #{inspect(invalid)}"
      end

    quote do
      previous_parent_namespace = @parent_namespace

      namespace =
        Namespace.new(
          unquote(segment),
          Keyword.put(unquote(opts), :parent, previous_parent_namespace)
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
    opts = Keyword.put(opts, :base, true)

    quote do
      namespace(unquote(segment), unquote(opts), do: unquote(block))
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
end
