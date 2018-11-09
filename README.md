# TestSHACL

Working with SHACL and Elixir - Applying SPARQL.ex to RDF shapes.

**TODO: Add description**

Following up on my last a project about querying RDF using the Elixir
`SPARQL.ex` and `SPARQL.Client.ex` libraries from Marcel Otto, I wanted
to focus here on a simple use case with SHACL and an RDF shape used to
provide a template description for the result graph. That is, instead of
using a specific SPARQL query we will generate SPARQL queries from the
RDF shape that defines the valid result graphs. And in doing so we will
also bump up against some limitations with the current `SPARQL.ex`
implementation and show how we might work around those.

## Review querying scenarios

## Create a `TestSHACL` project

As usual, let's create a new project `TestSHACL` with `mix` (and note
this time we use the `module` option to pass the desired project name
`TestSHACL` instead of the default casing `TestShacl`):

```bash
bash> mkdir test_shacl; cd test_shacl
bash> mix new . --module TestSHACL
```

We'll add the packages a static code analysis tools and test of the
notifier.

```elixir
# config/config.exs
use Mix.Config

if Mix.env == :dev do
  config :tesla, :adapter, Tesla.Adapter.Hackney
  config :mix_test_watch, clear: true
  config :remix, escript: true, silent: true
end

if Mix.env == :test do
  config :ex_unit_notifier,
    notifier: ExUnitNotifier.Notifiers.NotifySend
end

# import_config "#{Mix.env()}.exs"
```

```elixir
# test/test_helper.exs
ExUnit.configure formatters: [ExUnit.CLIFormatter, ExUnitNotifier]
ExUnit.start()
```

```elixir
# mix.exs
defmodule TestSHACL.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_shacl,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env)
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10.1", only: :test},
      {:ex_unit_notifier, "~> 0.1.4", only: :test},
      {:hackney, "~> 1.14.3"},
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:sparql_client, "~> 0.2.1"},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger]
end
```

Run it code: `bash> make packs; make all`

We'll then declare a dependency on `SPARQL.Client.ex` in the `mix.exs`
file. And we'll also use the `hackney` HTTP client in Erlang as
recommended. And we added this line to the `config.exs` file:
`config :tesla, :adapter, Tesla.Adapter.Hackney`. We then use Mix to add
in the dependency: `make packs`.

Let's also clear out the boilerplate in `lib/test_shacl.ex` and add in a
`@moduledoc` annotation. And we'll also add a module attribute
`@priv_dir` to locate our project artefacts directory `priv/`.


```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  @priv_dir "#{:code.priv_dir(:test_shacl)}"
end
```

We'll create a `lib/test_shacl/` directory for the client module we're
going to add in the file `client.ex`.

We'll also create the `priv/` directory tree.

```bash
bash> mkdir -p lib/test_shacl/
bash> touch lib/test_shacl/client.ex
bash> mkdir -p priv/data
bash> mkdir -p priv/shapes
bash> mkdir -p priv/shapes/queries
bash> touch priv/data/978-1-68050-252-7.ttl
bash> touch priv/shapes/book_shape.ttl
bash> touch priv/shapes/queries/book_shape_query.rq
bash> touch priv/shapes/queries/book_shape_query_helper.rq
```

And for testing let's also copy over the query convenience functions we
defined in the previously project for the `TestQuery` and
`TestQuery.Client` module. We'll copy `query/0`, `query/1` and `query/2`
to the `TestSHACL` module, and `rquery/0`, `rquery/1` and `rquery/2` to
the `TestSHACL.Client` module.

And also to simplify naming in IEx we'll add a `.iex.exs` configuration
file.

```elixir
# .iex.exs
import TestSHACL
import TestSHACL.Client
```

## Define a query for an RDF shape

Now let's reuse the same RDF description we have used in the last
projects.

```
# priv/data/978-1-68050-252-7.ttl
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

<urn:isbn:978-1-68050-252-7> a bibo:Book ;
    dc:creator <https://twitter.com/bgmarx> ;
    dc:creator <https://twitter.com/josevalim> ;
    dc:creator <https://twitter.com/redrapids> ;
    dc:date "2018-03-14"^^xsd:date ;
    dc:format "Paper" ;
    dc:publisher <https://pragprog.com/> ;
    dc:title "Adopting Elixir"@en .
```

As before, we can define a simple `data/0` function to retrieve this RDF
data from the file `978–1–68050–252–7.ttl` which we'll add to
`priv/data/`.


```elixir
# lib/test_shacl/client.ex
defmodule TestSHACL.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client module.
  """

  @priv_dir "#{:code.priv_dir(:test_shacl)}"

  @data_dir @priv_dir <> "/data/"
  @data_file "978-1-68050-252-7.ttl"

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    RDF.Turtle.read_file!(@data_dir <> @data_file)
  end
end
```

And let's try that.

```bash
bash> make all

iex> data
#=> #RDF.Graph{name: nil
        ~I<urn:isbn:978-1-68050-252-7>
            ~I<http://purl.org/dc/elements/1.1/creator>
              ~I<https://twitter.com/bgmarx>
              ~I<https://twitter.com/josevalim>
              ~I<https://twitter.com/redrapids>
            ~I<http://purl.org/dc/elements/1.1/date>
            %RDF.Literal{value: ~D[2018-03-14],
              datatype: ~I<http://www.w3.org/2001/XMLSchema#date>}
            ~I<http://purl.org/dc/elements/1.1/format>
              ~L"Paper"
            ~I<http://purl.org/dc/elements/1.1/publisher>
              ~I<https://pragprog.com/>
            ~I<http://purl.org/dc/elements/1.1/title>
              ~L"Adopting Elixir"en
            ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
              ~I<http://purl.org/ontology/bibo/Book>}

iex> data |> RDF.Turtle.write_string! |> IO.puts
#=> <urn:isbn:978-1-68050-252-7>
        a <http://purl.org/ontology/bibo/Book> ;
        <http://purl.org/dc/elements/1.1/creator>
          <https://twitter.com/bgmarx>,
          <https://twitter.com/josevalim>,
          <https://twitter.com/redrapids> ;
        <http://purl.org/dc/elements/1.1/date>
          "2018-03-14"^^<http://www.w3.org/2001/XMLSchema#date> ;
        <http://purl.org/dc/elements/1.1/format> "Paper" ;
        <http://purl.org/dc/elements/1.1/publisher> <https://pragprog.com/> ;
        <http://purl.org/dc/elements/1.1/title> "Adopting Elixir"@en .
    :ok
```

Looks good. No prefix forms here but it is a valid RDF description. So
now to defining an RDF shape for this graph.

The new W3C standard for RDF introduced last year, the Shapes Constraint
Langauge (SHACL), has been a very significant development for RDF as it
specifies a "language for describing and validating RDF graphs".
While most attention is usually focused on the validation part, the
really unique value proposition of SHACL is its formalization of RDF
graph descriptions. Because, of course, before validating a graph one
needs to be able to define it properly. And the fact that RDF shapes in
SHACL are themselves modelled as RDF means that these graph descriptions
 can be queried over in turn as native data constructs. This is powerful.
This is very much the "code is data" paradigm.

SHACL defines two basic types of shapes:

* shapes about a focus node, called node shapes
* shapes about the values of a particular property or path for the focus
  node, called property shapes

Our use case here is based on a node shape. The set of focus nodes for a
node shape may be identified using target declarations via the
`sh:targetClass` property. In this use case we have but one focus node
which is identified with the `sh:targetClass` of `bibo:Book`.

Now we can define a basic RDF shape for our book description as below.
And for the purposes of this tutorial let's expressly comment out a
couple properties: `dc:format` and `dc:publisher`. This leaves just
`dc:creator`, `dc:date` and `dc:title`. Let's assume for whatever reason
that we wish to limit our book descriptions to just title, author and
date. (This example is admittedly more than a little contrived but it
will serve our purposes here in defining a proper subgraph.)

```
# priv/shapes/book_shape.ttl
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

@prefix shapes: <http://example.org/shapes/> .

# shape - Book

shapes:Book
    a sh:NodeShape ;
    sh:targetClass bibo:Book ;
    rdfs:label "SHACL shape for the bibo:Book model" ;
    sh:closed true ;

    sh:property [ sh:path dc:creator ] ;
    sh:property [ sh:path dc:date ] ;
    # sh:property [ sh:path dc:format ] ;
    # sh:property [ sh:path dc:publisher ] ;
    sh:property [ sh:path dc:title ] ;
    .
```

We can define a simple `shape/0` function to retrieve the shape from
the file `book_shape.ttl` which we'll add to `priv/shapes/`.


```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  @shapes_dir @priv_dir <> "/shapes/"
  @shape_file "book_shape.ttl"

  # ...

  @doc """
  Reads default RDF shape in Turtle format.
  """
  def shape do
    RDF.Turtle.read_file!(@shapes_dir <> @shape_file)
  end
end
```

And again let's try that.

```bash
bash> make all
iex> shape |> RDF.Turtle.write_string! |> IO.puts
#=> <http://example.org/shapes/Book>
        a <http://www.w3.org/ns/shacl#NodeShape> ;
        <http://www.w3.org/2000/01/rdf-schema#label> "SHACL shape for the bibo:Book model" ;
        <http://www.w3.org/ns/shacl#closed> true ;
        <http://www.w3.org/ns/shacl#property> [
            <http://www.w3.org/ns/shacl#path> <http://purl.org/dc/elements/1.1/creator>
        ], [
            <http://www.w3.org/ns/shacl#path> <http://purl.org/dc/elements/1.1/date>
        ], [
            <http://www.w3.org/ns/shacl#path> <http://purl.org/dc/elements/1.1/title>
        ] ;
        <http://www.w3.org/ns/shacl#targetClass> <http://purl.org/ontology/bibo/Book> .
    :ok
```

So, we're going to define a query for this shape in the file
`book_shape_query.rq` which we'll add to `priv/shapes/queries/`.

```
# priv/shapes/queries/book_shape_query.rq
prefix bibo: <http://purl.org/ontology/bibo/>
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sh: <http://www.w3.org/ns/shacl#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>

prefix shapes: <http://example.org/shapes/>

construct {
  ?s ?p ?o
}
where {
  {
    select distinct ?p
    where {
      ?shape sh:targetClass bibo:Book .
      ?shape sh:property [ sh:path ?p ] .
    }
  }
  ?s a bibo:Book .
  ?s ?p ?o .
}
```

The query pattern here is to use an inner query (a `select` query)
against an RDF shape to get a list of allowed properties for a given
class (identified by the `sh:targetClass`) and to use that to drive a
`construct` query which matches instances of that class and decorates
them with the allowed properties. Basically we're retrieving RDF
descriptions for things which are restricted to the property list
specified in the RDF shape. In our case here we're looking for instances
of a book class (specifically a `bibo:Book`).

### 8 Novem8er 2018 by Oleg G.Kapranov
