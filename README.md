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

  ## Data access functions for graphs

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

We'll also define a convenience function `shape_query/0` to read this
query.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  ## Data access functions for queries

  @shapes_queries_dir @priv_dir <> "/shapes/queries/"
  @shape_query_file "book_shape_query.rq"

  @doc """
  Reads default SPARQL query for default RDF shape.
  """
  def shape_query do
    File.read!(@shapes_queries_dir <> @shape_query_file)
  end
end
```

Now, we can verify this query by running against a local triplestore.
Here I'm using GraphDB Free edition (version 8.7.2 Debian based Linux) from Ontotext with a
new repo `shape-test` which just includes the `data` and the `shape`
graphs. (In a production system we would typically use named graphs to
organize the data but here it is not necessary.)

Setup GraphDB in Debian based Linux:

```bash
bash> sudo dpkg -i graphdb-free-8.7.2.deb
bash> env | grep PATH
bash> cat >> .bashrc
export PATH="/opt/GraphDBFree:$PATH"

bash> $BASH
bash> GraphDBFree
```

and then open web brouser on some url: `http://localhost:7200/`

1. create repository

![graphdb](/screenshots1.png "create repository")

2. uploaded RDF files - `book_shape.ttl`

![graphdb](/screenshots2.png "upload files")

3. SPARQL - query

![graphdb](/screenshots3.png "sparql query")

It works!

We have just those properties we defined in the RDF shape, and not those
we commented.

## Query in-memory RDF models

So let's try now to emulate this with `SPARQL.ex`, not with standing any
known limitations.

First let's replicate the repo `shape_test` by using the
`RDF.Graph.add/2` function to merge the two graphs `data` and `shape`:

```bash
bash> make all
iex> shape_test = RDF.Graph.add(data, shape)
#=> #RDF.Graph{name: nil
        ~B<b0>
          ~I<http://www.w3.org/ns/shacl#path>
            ~I<http://purl.org/dc/elements/1.1/creator>
        ~B<b1>
          ~I<http://www.w3.org/ns/shacl#path>
            ~I<http://purl.org/dc/elements/1.1/date>
        ~B<b2>
          ~I<http://www.w3.org/ns/shacl#path>
            ~I<http://purl.org/dc/elements/1.1/title>
        ~I<http://example.org/shapes/Book>
          ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>
            ~I<http://www.w3.org/ns/shacl#NodeShape>
          ~I<http://www.w3.org/2000/01/rdf-schema#label>
            ~L"SHACL shape for the bibo:Book model"
          ~I<http://www.w3.org/ns/shacl#closed>
            %RDF.Literal{value: true,
              datatype: ~I<http://www.w3.org/2001/XMLSchema#boolean>}
          ~I<http://www.w3.org/ns/shacl#property>
            ~B<b0>
            ~B<b1>
            ~B<b2>
          ~I<http://www.w3.org/ns/shacl#targetClass>
            ~I<http://purl.org/ontology/bibo/Book>
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
```

And note that this RDF.Graph serialization also shows blank nodes marked
with the `~B` sigil, alongside the IRIs marked with the `-I` sigil, and
literals marked with the the `~L` sigil.

Now if we try and run our query against this we get this:

```bash
iex> SPARQL.execute_query(shape_test, shape_query)
#=> %SPARQL.Query.Result{
      results: [
        %{
          "o" => ~I<https://twitter.com/bgmarx>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/josevalim>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/redrapids>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          o" => %RDF.Literal{value: ~D[2018-03-14],
                  datatype: ~I<http://www.w3.org/2001/XMLSchema#date>},
          "p" => ~I<http://purl.org/dc/elements/1.1/date>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Paper",
          "p" => ~I<http://purl.org/dc/elements/1.1/format>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://pragprog.com/>,
          "p" => ~I<http://purl.org/dc/elements/1.1/publisher>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Adopting Elixir"en,
          "p" => ~I<http://purl.org/dc/elements/1.1/title>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<http://purl.org/ontology/bibo/Book>,
          "p" => ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        }
      ],
      variables: ["s", "p", "o"]
    }
```

Well, this is a little surprising. We're getting a `SPARQL.Query.Result`
struct which we'd expect from a `select` query – not from a `construct`
query. Also we're getting all of the properties from our `data` graph
returned, so it looks as though our inner query using the `shape` graph
has been ignored.

And if we check the documentation for `SPARQL.ex` we see that indeed a
whole bunch of things are still on the to-do list, among them `construct`
and inner queries. (Which is fair enough – it takes time to implement a
complete spec and SPARQL is one of the larger suites of specifications
from the W3C.)

**Build a query for an RDF shape**

So, let's try and reimagine our approach. We'll ditch the inner query
and build the `shape_query` using a function instead.

For this we'll make use of a simpler `book_shape_query_helper.rq` query
and we'll aim to just make a select of the properties `?p` for a given
subject `?s`.

Now we would like to set the `sh:targetClass` to a given class
(`bibo:Book`) via the bound variable `?s` as a way of generalizing, but
since `SPARQL.ex` does not support the `bind` keyword we will make do in
this example by setting `sh:targetClass` to the unbound variable `?s`
and also to the given class.

```
# priv/shapes/queries/book_shape_query_helper.rq
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

@prefix shapes: <http://example.org/shapes/> .

select distinct ?s ?p
where {
  # bind (bibo:Book as ?s)
  ?shape sh:targetClass bibo:Book .
  ?shape sh:targetClass ?s .
  ?shape sh:property [ sh:path ?p ] .
}
```
And again we define a convenience function `shape_query_helper/0` to
read this query.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  @shapes_queries_dir @priv_dir <> "/shapes/queries/"
  @shape_query_helper_file "book_shape_query_helper.rq"

  # ...

  @doc """
  Reads simple SPARQL query for default RDF shape.
  """
  def shape_query_helper do
    File.read!(@shapes_queries_dir <> @shape_query_helper_file)
  end
end
```

So we can now provide a very basic query builder `query_from_shape/2`
which applies a `shape_query` to the `shape`.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  @doc """
  Makes a SPARQL query by querying default RDF shape - demo only.
  """
  def query_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    # add the subject type
    s = result |> SPARQL.Query.Result.get(:s) |> List.first
    q = qh <> "  ?s a <#{s}> .\n"

    # add the properties
    q = q <> List.to_string(
      result
      |> SPARQL.Query.Result.get(:p)
      |> Enum.map(&("  ?s <#{&1}> ?o .\n  ?s ?p ?o .\n"))
    )
    q <> qt
  end
end
```

Now we would like to set the property in the triple pattern to be the
variable `?p` bound to the actual property, but since `SPARQL.ex`
does not support the `bind` keyword we will make do by using two triple
patterns –  one with the actual property and one with the variable `?p`
as the property. (And I should point out that this is an unashamed hack
and will only work for this tutorial since we are running the query
against a known dataset with just one RDF description.)

In our case the `shape_query` argument applied will be the query from
`shape_query_helper/0`. And running this we get:

```bash
bash> make all
iex> query_from_shape(shape, shape_query_helper) |> IO.puts
#=> select ?s ?p ?o
    where {
      ?s a <http://purl.org/ontology/bibo/Book> .
      ?s <http://purl.org/dc/elements/1.1/creator> ?o .
      ?s ?p ?o .
      ?s <http://purl.org/dc/elements/1.1/date> ?o .
      ?s ?p ?o .
      ?s <http://purl.org/dc/elements/1.1/title> ?o .
      ?s ?p ?o .
    }
    :ok
```

But this is not going to work. It would work for a single property only
but for multiple properties can only match if this was a union over
separate graph patterns – and `SPARQL.ex` does not currently support
`union`. We're going to need something more radical.

What we'll need to do is generate instead a list of queries – one query
for each property. So let's try that.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  @doc """
  Makes a list of SPARQL queries by querying default RDF shape.
  """
  def queries_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    # get the subject
    s = result |> SPARQL.Query.Result.get(:s) |> List.first

    # get the properties
    (result |> SPARQL.Query.Result.get(:p))
    |> Enum.map(
      &(qh
        <> "  # bind (<#{&1}> as ?p)\n"
        <> "  ?s a <#{s}> .\n"
        <> "  ?s <#{&1}> ?o .\n"
        <> " ?s ?p ?o .\n"
        <> qt
      )
    )
  end
end
```

How does this now look? (And we’ll pipe this through `Enum.map/2` with
`String.duplicate/2` function to add in a line separator.)

```bash
bash> make all
iex> queries_from_shape(shape, shape_query_helper) \
     |> Enum.map(&(String.duplicate("#",60) <> "\n" <> &1)) \
     |> IO.puts
#=> ############################################################
    select ?s ?p ?o
    where {
      # bind (<http://purl.org/dc/elements/1.1/creator> as ?p)
      ?s a <http://purl.org/ontology/bibo/Book> .
      ?s <http://purl.org/dc/elements/1.1/creator> ?o .
      ?s ?p ?o .
    }
    ############################################################
    select ?s ?p ?o
    where {
      # bind (<http://purl.org/dc/elements/1.1/date> as ?p)
      ?s a <http://purl.org/ontology/bibo/Book> .
      ?s <http://purl.org/dc/elements/1.1/date> ?o .
      ?s ?p ?o .
    }
    ############################################################
    select ?s ?p ?o
    where {
      # bind (<http://purl.org/dc/elements/1.1/title> as ?p)
      ?s a <http://purl.org/ontology/bibo/Book> .
      ?s <http://purl.org/dc/elements/1.1/title> ?o .
      ?s ?p ?o .
    }

    :ok
```

Well, that looks better.

##  Transform result sets to RDF graph

One thing we haven't really discussed yet is how to transform from the
`SPARQL.Query.Result` struct resulting from a `select` query to an
`RDF.Graph` which would result from a `construct` query.

The `to_graph/4` function shown here is cribbed from
`SPARQL.Query.Result.get/1` and extends the function signature from one
variable to three variables for an RDF triple. It just selects for three
named fields (the variables named as arguments) from each map in the list
and wraps those up as a regular tuple (the RDF triple) with the
`RDF.triple/3` function. The resulting list of triples is then returned
as an `RDF.Graph` using the `RDF.graph/1` function.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  @query """
  select *
  where {
    ?s ?p ?o
  }
  """

  # ...

  @doc """
  Queries default RDF model with default SPARQL query.
  """
  def query do
    query(@query)
  end

  @doc """
  Queries default RDF model with user SPARQL query.
  """
  def query(query) do
    qr = Turtle.read_file!(@data_dir <> @data_file)
    qr |> SPARQL.execute_query(query)
  end

  @doc """
  Queries a user RDF model with a user SPARQL query.
  """
  def query(graph, query) do
    SPARQL.execute_query(graph, query)
  end

  # ...

  @doc """
  Transforms a SPARQL.Query.Result struct into an RDF graph.
  """
  def to_graph(%SPARQL.Query.Result{results: results, variables: variables},
               variable1, variable2, variable3) do
    if variable1 in variables
      and variable2 in variables
      and variable3 in variables
    do
      triples =
        Enum.map results,
          fn r ->
            RDF.triple(r[variable1], r[variable2], r[variable3])
          end
      RDF.graph(triples)
    end
  end
end
```

And for convenience we also support passing the variables as atoms
instead of strings.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  # ...

  ## Transform function from results table to graph

  @doc """
  Helper function clause for converting atom args to strings.
  """
  def to_graph(result, variable1, variable2, variable3)
      when is_atom(variable1) and is_atom(variable2) and is_atom(variable3),
    do: to_graph(result, to_string(variable1), to_string(variable2), to_string(variable3))
  end

  # ...
end
```
So let's try with our default query (running against the default RDF
description) which simply makes a `select` over all our `?s`, `?p`, and
`?o` variables.

```elixir
# lib/test_shacl.ex
defmodule TestSHACL do
  @moduledoc """
  Top-level module used in "Working with SHACL and Elixir"
  """

  alias RDF.Turtle
  alias SPARQL.Query.Result

  @priv_dir "#{:code.priv_dir(:test_shacl)}"

  @data_dir @priv_dir <> "/data/"
  @data_file "978-1-68050-252-7.ttl"

  @shapes_dir @priv_dir <> "/shapes/"
  @shape_file "book_shape.ttl"

  @shapes_queries_dir @priv_dir <> "/shapes/queries/"
  @shape_query_file "book_shape_query.rq"
  @shape_query_helper_file "book_shape_query_helper.rq"

  @query """
  select *
  where {
    ?s ?p ?o
  }
  """

  @doc """
  Reads default RDF model in Turtle format.
  """
  def data do
    Turtle.read_file!(@data_dir <> @data_file)
  end

  @doc """
  Reads default RDF shape in Turtle format.
  """
  def shape do
    Turtle.read_file!(@shapes_dir <> @shape_file)
  end

  @doc """
  Reads default SPARQL query for default RDF shape.
  """
  def shape_query do
    File.read!(@shapes_queries_dir <> @shape_query_file)
  end

  @doc """
  Reads simple SPARQL query for default RDF shape.
  """
  def shape_query_helper do
    File.read!(@shapes_queries_dir <> @shape_query_helper_file)
  end

  @doc """
  Queries default RDF model with default SPARQL query.
  """
  def query do
    query(@query)
  end

  @doc """
  Queries default RDF model with user SPARQL query.
  """
  def query(query) do
    qr = Turtle.read_file!(@data_dir <> @data_file)
    qr |> SPARQL.execute_query(query)
  end

  @doc """
  Queries a user RDF model with a user SPARQL query.
  """
  def query(graph, query) do
    SPARQL.execute_query(graph, query)
  end

  @doc """
  Makes a SPARQL query by querying default RDF shape - demo only.
  """
  def query_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    s = result |> Result.get(:s) |> List.first
    q = qh <> "  ?s a <#{s}> .\n"

    q = q <> List.to_string(
      result
      |> Result.get(:p)
      |> Enum.map(&("  ?s <#{&1}> ?o .\n  ?s ?p ?o .\n"))
    )
    q <> qt
  end

  @doc """
  Makes a list of SPARQL queries by querying default RDF shape.
  """
  def queries_from_shape(shape, shape_query) do
    qh = "select ?s ?p ?o\nwhere {\n"
    qt = "}\n"

    result = SPARQL.execute_query(shape, shape_query)

    s = result |> Result.get(:s) |> List.first

    (result |> Result.get(:p))
    |> Enum.map(
      &(qh
        <> "  # bind (<#{&1}> as ?p)\n"
        <> "  ?s a <#{s}> .\n"
        <> "  ?s <#{&1}> ?o .\n"
        <> " ?s ?p ?o .\n"
        <> qt
      )
    )
  end

  @doc """
  Helper function clause for converting atom args to strings.
  """
  def to_graph(result, variable1, variable2, variable3)
      when is_atom(variable1) and is_atom(variable2) and is_atom(variable3),
    do: to_graph(result, to_string(variable1), to_string(variable2), to_string(variable3))

  @doc """
  Transforms a SPARQL.Query.Result struct into an RDF graph.
  """
  def to_graph(%SPARQL.Query.Result{results: results, variables: variables},
               variable1, variable2, variable3) do
    if variable1 in variables
      and variable2 in variables
      and variable3 in variables
    do
      triples =
        Enum.map results,
          fn r ->
            RDF.triple(r[variable1], r[variable2], r[variable3])
          end
      RDF.graph(triples)
    end
  end
end
```

```bash
bash> make all

iex> query
#=> %SPARQL.Query.Result{
      results: [
        %{
          "o" => ~I<https://twitter.com/bgmarx>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/josevalim>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://twitter.com/redrapids>,
          "p" => ~I<http://purl.org/dc/elements/1.1/creator>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => %RDF.Literal{value: ~D[2018-03-14],
            datatype: ~I<http://www.w3.org/2001/XMLSchema#date>},
          "p" => ~I<http://purl.org/dc/elements/1.1/date>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Paper",
          "p" => ~I<http://purl.org/dc/elements/1.1/format>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<https://pragprog.com/>,
          "p" => ~I<http://purl.org/dc/elements/1.1/publisher>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~L"Adopting Elixir"en,
          "p" => ~I<http://purl.org/dc/elements/1.1/title>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        },
        %{
          "o" => ~I<http://purl.org/ontology/bibo/Book>,
          "p" => ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>,
          "s" => ~I<urn:isbn:978-1-68050-252-7>
        }
      ],
      variables: ["s", "p", "o"]
    }

iex> query |> to_graph(:s, :p, :o)
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
```

And let's try this now on our `queries_from_shape/2` function:

```bash
iex> queries_from_shape(shape, shape_query_helper) \
     |> Enum.map(&query/1) \
     |> Enum.map(&(to_graph(&1, :s, :p, :o)))
#=> [
      #RDF.Graph{name: nil
        ~I<urn:isbn:978-1-68050-252-7>
          ~I<http://purl.org/dc/elements/1.1/creator>
            ~I<https://twitter.com/bgmarx>
            ~I<https://twitter.com/josevalim>
            ~I<https://twitter.com/redrapids>},
      #RDF.Graph{name: nil
        ~I<urn:isbn:978-1-68050-252-7>
          ~I<http://purl.org/dc/elements/1.1/date>
            %RDF.Literal{value: ~D[2018-03-14],
              datatype: ~I<http://www.w3.org/2001/XMLSchema#date>}},
      #RDF.Graph{name: nil
        ~I<urn:isbn:978-1-68050-252-7>
          ~I<http://purl.org/dc/elements/1.1/title>
            ~L"Adopting Elixir"en}
    ]
```

Just one thing left – to merge those graphs. And using the IEx helper
`v()` to recall the last value from the IEx history. We use the
`RDF.Graph.add/2` function within `List.foldl/3` to aggregate the graphs
via an accumulator supplied by `RDF.Graph.new/0`.

```bash
iex> v() |> List.foldl(RDF.Graph.new, fn g1, g2 ->
       RDF.Graph.add(g1, g2) end)
#=> #RDF.Graph{name: nil
      ~I<urn:isbn:978-1-68050-252-7>
        ~I<http://purl.org/dc/elements/1.1/creator>
          ~I<https://twitter.com/bgmarx>
          ~I<https://twitter.com/josevalim>
          ~I<https://twitter.com/redrapids>
        ~I<http://purl.org/dc/elements/1.1/date>
          %RDF.Literal{value: ~D[2018-03-14],
            datatype: ~I<http://www.w3.org/2001/XMLSchema#date>}
        ~I<http://purl.org/dc/elements/1.1/title>
          ~L"Adopting Elixir"en}
```
Or, more meaningfully as a Turtle string, and again using the `v()`
helper.

```bash
iex> v() |> RDF.Turtle.write_string! |> IO.puts
#=> <urn:isbn:978-1-68050-252-7>
      <http://purl.org/dc/elements/1.1/creator> <https://twitter.com/bgmarx>,
        <https://twitter.com/josevalim>, <https://twitter.com/redrapids> ;
      <http://purl.org/dc/elements/1.1/date> "2018-03-14"^^<http://www.w3.org/2001/XMLSchema#date> ;
      <http://purl.org/dc/elements/1.1/title> "Adopting Elixir"@en .
    :ok
```

So, that graph is retrieved from the RDF data using our RDF shape to
filter out properties (or rather, to select for only those properties we
actually want).

### 8 Novem8er 2018 by Oleg G.Kapranov

[1]: http://graphdb.ontotext.com/
[2]: https://www.ontotext.com/thank-you-graphdb-free/
[3]: http://graphdb.ontotext.com/documentation/free/quick-start-guide.html
[4]: https://github.com/tonyhammond/examples/tree/master/test_shacl
[5]: https://medium.com/@tonyhammond/working-with-shacl-and-elixir-4719473d43c1
