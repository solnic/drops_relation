defprotocol Drops.Relation.Loadable do
  @moduledoc false

  @spec load(struct(), map()) :: Drops.Relation.Loaded.t()
  def load(queryable, meta \\ %{})
end
