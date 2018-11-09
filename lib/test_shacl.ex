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
