defprotocol Drops.SQL.Types.Conversion do
  @spec to_atom(term(), term()) :: atom()
  def to_atom(table, type)

  @spec to_ecto_type(term(), term()) :: any()
  def to_ecto_type(table, column)
end
