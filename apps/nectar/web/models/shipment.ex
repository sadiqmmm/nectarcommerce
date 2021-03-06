defmodule Nectar.Shipment do
  use Nectar.Web, :model

  schema "shipments" do
    belongs_to :shipping_method, Nectar.ShippingMethod
    belongs_to :shipment_unit, Nectar.ShipmentUnit
    has_one    :adjustment, Nectar.Adjustment
    timestamps
  end

  @required_fields ~w(shipping_method_id)a
  @optional_fields ~w()a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def create_changeset(model, params \\ %{}) do
    model
    |> cast(params_with_adjustment(model, params), @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> cast_assoc(:adjustment)
  end

  defp params_with_adjustment(_model, params) do
    Map.put_new(params, "adjustment", %{"amount" => params["shipping_cost"], "order_id" => params["order_id"]})
  end

end
