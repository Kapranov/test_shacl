defmodule TestSHACL.Client do
  @moduledoc """
  This module provides test functions for the SPARQL.Client module.
  """

  alias SPARQL.Client

  @service "http://localhost:7200/repositories/shape-test"

  @query """
  select *
  where {
    ?s ?p ?o
  }
  """

  def get_service, do: @service

  @doc """
  Queries default RDF service with default SPARQL query.
  """
  def rquery do
    Client.query(@query, @service)
  end

  @doc """
  Queries default RDF service with user SPARQL query.
  """
  def rquery(query) do
    Client.query(query, @service)
  end

  @doc """
  Queries a user RDF service with a user SPARQL query.
  """
  def rquery(query, service) do
    Client.query(query, service)
  end
end
