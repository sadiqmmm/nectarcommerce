defmodule Nectar.Variant do
  use Nectar.Web, :model
  use Arc.Ecto.Model

  schema "variants" do
    field :is_master, :boolean, default: false
    field :sku, :string
    field :weight, :decimal
    field :height, :decimal
    field :width, :decimal
    field :depth, :decimal
    field :discontinue_on, Ecto.Date
    field :cost_price, :decimal
    field :cost_currency, :string
    field :image, Nectar.VariantImage.Type

    field :total_quantity, :integer, default: 0
    field :add_count, :integer, virtual: true

    field :bought_quantity, :integer, default: 0
    field :buy_count, :integer, virtual: true

    field :restock_count, :integer, virtual: true

    belongs_to :product, Nectar.Product
    has_many :variant_option_values, Nectar.VariantOptionValue, on_delete: :delete_all, on_replace: :delete
    has_many :option_values, through: [:variant_option_values, :option_value]

    has_many :line_items, Nectar.LineItem

    timestamps
    extensions
  end

  @required_fields ~w(is_master discontinue_on cost_price)a
  @optional_fields ~w(sku weight height width depth cost_currency add_count)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> Validations.Date.validate_not_past_date(:discontinue_on)
    |> validate_number(:add_count, greater_than: 0)
    |> update_total_quantity
  end

  @required_fields ~w(cost_price)a
  @optional_fields ~w(add_count discontinue_on)a
  def create_master_changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> update_total_quantity
    |> put_change(:is_master, true)
    |> validate_number(:add_count, greater_than: 0)
    |> cast_attachments(params, ~w(), ~w(image))
  end

  @required_fields ~w(cost_price discontinue_on)a
  @optional_fields ~w(add_count)a
  def update_master_changeset(model, product, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> Validations.Date.validate_not_past_date(:discontinue_on)
    |> validate_discontinue_gt_available_on(product)
    |> update_total_quantity
    |> put_change(:is_master, true)
    |> validate_number(:add_count, greater_than: 0)
    |> check_is_master_changed
    # Even if changset is invalid, cast_attachments does it work :(
    |> cast_attachments(params, ~w(), ~w(image))
  end

  defp check_is_master_changed(changeset) do
    if get_change(changeset, :is_master) do
      add_error(changeset, :is_master, "appears to assign another variant as master variant")
      |> add_error(:base, "Please check whether your Master Variant is deleted :(")
    else
      changeset
    end
  end

  def create_variant_changeset(model, product, params \\ %{}) do
    changeset(model, params)
    |> validate_discontinue_gt_available_on(product)
    |> put_change(:is_master, false)
    |> cast_attachments(params, ~w(), ~w(image))
    |> cast_assoc(:variant_option_values, required: true, with: &Nectar.VariantOptionValue.from_variant_changeset/2)
  end

  def update_variant_changeset(model, product, params \\ %{}) do
    changeset(model, params)
    |> validate_discontinue_gt_available_on(product)
    |> validate_not_master
    # Even if changset is invalid, cast_attachments does it work :(
    |> cast_attachments(params, ~w(), ~w(image))
    |> cast_assoc(:variant_option_values, required: true, with: &Nectar.VariantOptionValue.from_variant_changeset/2)
  end

  defp validate_not_master(changeset) do
    if changeset.data.is_master do
      add_error(changeset, :is_master, "can't be updated")
      |> add_error(:base, "Please go to Product Edit Page to update master variant")
    else
      changeset
    end
  end

  @required_fields ~w(buy_count)a
  @optional_fields ~w()a
  def buy_changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:buy_count, greater_than: 0)
    |> increment_bought_quantity
  end

  @required_fields ~w(restock_count)a
  @optional_fields ~w()
  def restocking_changeset(model, params) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:restock_count, greater_than: 0)
    |> decrement_bought_quantity
  end

  defp update_total_quantity(model) do
    quantity_to_add = model.changes[:add_count]
    if quantity_to_add do
      put_change(model, :total_quantity, model.data.total_quantity + quantity_to_add)
    else
      model
    end
  end

  defp increment_bought_quantity(model) do
    quantity_to_add = model.changes[:buy_count]
    if quantity_to_add do
      put_change(model, :bought_quantity, (model.data.bought_quantity || 0) + quantity_to_add)
    else
      model
    end
  end

  defp decrement_bought_quantity(model) do
    quantity_to_subtract = model.changes[:restock_count]
    if quantity_to_subtract do
      put_change(model, :bought_quantity, (model.data.bought_quantity || 0) - quantity_to_subtract)
    else
      model
    end
  end

  def available_quantity(%Nectar.Variant{total_quantity: total_quantity, bought_quantity: bought_quantity}) when is_nil(bought_quantity) do
    total_quantity
  end

  def available_quantity(%Nectar.Variant{total_quantity: total_quantity, bought_quantity: bought_quantity}) do
    total_quantity - bought_quantity
  end

  def display_name(variant) do
    product = variant |> Nectar.Repo.preload([:product]) |> Map.get(:product)
    "#{product.name}(#{variant.sku})"
  end

  defp validate_discontinue_gt_available_on(changeset, product) do
    changeset
    |> Validations.Date.validate_gt_date(:discontinue_on, product.available_on)
  end
end
