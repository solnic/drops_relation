defprotocol Drops.SQL.Types.Conversion do
  @spec to_ecto_type(term(), term()) :: any()
  def to_ecto_type(table, column)
end
