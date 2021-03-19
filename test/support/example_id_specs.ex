defmodule Example.IdSpec do
  defmodule FlatNs do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
    end
  end

  defmodule FlatNsWithVocabTerms do
    use Grax.Id.Spec

    alias Example.NS.EX

    namespace EX, prefix: :ex do
    end
  end

  defmodule FlatBase do
    use Grax.Id.Spec

    alias Example.NS.EX

    base EX do
    end
  end

  defmodule NestedNs do
    use Grax.Id.Spec

    namespace "http://example.com/", prefix: :ex do
      namespace "foo/", prefix: :foo do
        namespace "bar/", prefix: :bar
        namespace "baz/", prefix: :baz
      end

      namespace "qux/", prefix: :qux
    end
  end
end
