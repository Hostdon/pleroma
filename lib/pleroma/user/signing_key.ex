defmodule Pleroma.User.SigningKey do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  require Pleroma.Constants
  alias Pleroma.User
  alias Pleroma.Repo

  require Logger

  @primary_key false
  schema "signing_keys" do
    belongs_to(:user, Pleroma.User, type: FlakeId.Ecto.CompatType)
    field :public_key, :string
    field :private_key, :string
    # This is an arbitrary field given by the remote instance
    field :key_id, :string, primary_key: true
    timestamps()
  end

  def load_key(%User{} = user) do
    user
    |> Repo.preload(:signing_key)
  end

  def key_id_of_local_user(%User{local: true} = user) do
    case Repo.preload(user, :signing_key) do
      %User{signing_key: %__MODULE__{key_id: key_id}} -> key_id
      _ -> nil
    end
  end

  @spec remote_changeset(__MODULE__, map) :: Changeset.t()
  def remote_changeset(%__MODULE__{} = signing_key, attrs) do
    signing_key
    |> cast(attrs, [:public_key, :key_id])
    |> validate_required([:public_key, :key_id])
  end

  @spec key_id_to_user_id(String.t()) :: String.t() | nil
  @doc """
  Given a key ID, return the user ID associated with that key.
  Returns nil if the key ID is not found.
  """
  def key_id_to_user_id(key_id) do
    from(sk in __MODULE__, where: sk.key_id == ^key_id)
    |> select([sk], sk.user_id)
    |> Repo.one()
  end

  @spec key_id_to_ap_id(String.t()) :: String.t() | nil
  @doc """
  Given a key ID, return the AP ID associated with that key.
  Returns nil if the key ID is not found.
  """
  def key_id_to_ap_id(key_id) do
    Logger.debug("Looking up key ID: #{key_id}")

    from(sk in __MODULE__, where: sk.key_id == ^key_id)
    |> join(:inner, [sk], u in User, on: sk.user_id == u.id)
    |> select([sk, u], u.ap_id)
    |> Repo.one()
  end

  @spec generate_rsa_pem() :: {:ok, binary()}
  @doc """
  Generate a new RSA private key and return it as a PEM-encoded string.
  """
  def generate_rsa_pem do
    key = :public_key.generate_key({:rsa, 2048, 65_537})
    entry = :public_key.pem_entry_encode(:RSAPrivateKey, key)
    pem = :public_key.pem_encode([entry]) |> String.trim_trailing()
    {:ok, pem}
  end

  @spec generate_local_keys(String.t()) :: {:ok, Changeset.t()} | {:error, String.t()}
  @doc """
  Generate a new RSA key pair and create a changeset for it
  """
  def generate_local_keys(ap_id) do
    {:ok, private_pem} = generate_rsa_pem()
    {:ok, local_pem} = private_pem_to_public_pem(private_pem)

    %__MODULE__{}
    |> change()
    |> put_change(:public_key, local_pem)
    |> put_change(:private_key, private_pem)
    |> put_change(:key_id, local_key_id(ap_id))
  end

  @spec local_key_id(String.t()) :: String.t()
  @doc """
  Given an AP ID, return the key ID for the local user.
  """
  def local_key_id(ap_id) do
    ap_id <> "#main-key"
  end

  @spec private_pem_to_public_pem(binary) :: {:ok, binary()} | {:error, String.t()}
  @doc """
  Given a private key in PEM format, return the corresponding public key in PEM format.
  """
  def private_pem_to_public_pem(private_pem) do
    [private_key_code] = :public_key.pem_decode(private_pem)
    private_key = :public_key.pem_entry_decode(private_key_code)
    {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} = private_key
    public_key = {:RSAPublicKey, modulus, exponent}
    public_key = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    {:ok, :public_key.pem_encode([public_key])}
  end

  @spec public_key(__MODULE__) :: {:ok, binary()} | {:error, String.t()}
  @doc """
  Return public key data in binary format.
  """
  def public_key_decoded(%__MODULE__{public_key: public_key_pem}) do
    decoded =
      public_key_pem
      |> :public_key.pem_decode()
      |> hd()
      |> :public_key.pem_entry_decode()

    {:ok, decoded}
  end

  def public_key(_), do: {:error, "key not found"}

  def public_key_pem(%User{} = user) do
    case Repo.preload(user, :signing_key) do
      %User{signing_key: %__MODULE__{public_key: public_key_pem}} -> {:ok, public_key_pem}
      _ -> {:error, "key not found"}
    end
  end

  def public_key_pem(_e) do
    {:error, "key not found"}
  end

  @spec private_key(User.t()) :: {:ok, binary()} | {:error, String.t()}
  @doc """
  Given a user, return the private key for that user in binary format.
  """
  def private_key(%User{} = user) do
    case Repo.preload(user, :signing_key) do
      %{signing_key: %__MODULE__{private_key: private_key_pem}} ->
        key =
          private_key_pem
          |> :public_key.pem_decode()
          |> hd()
          |> :public_key.pem_entry_decode()

        {:ok, key}

      _ ->
        {:error, "key not found"}
    end
  end

  @spec get_or_fetch_by_key_id(String.t()) :: {:ok, __MODULE__} | {:error, String.t()}
  @doc """
  Given a key ID, return the signing key associated with that key.
  Will either return the key if it exists locally, or fetch it from the remote instance.
  """
  def get_or_fetch_by_key_id(key_id) do
    case Repo.get_by(__MODULE__, key_id: key_id) do
      nil ->
        fetch_remote_key(key_id)

      key ->
        {:ok, key}
    end
  end

  @spec fetch_remote_key(String.t()) :: {:ok, __MODULE__} | {:error, String.t()}
  @doc """
  Fetch a remote key by key ID.
  Will send a request to the remote instance to get the key ID.
  This request should, at the very least, return a user ID and a public key object.
  Though bear in mind that some implementations (looking at you, pleroma) may require a signature for this request.
  This has the potential to create an infinite loop if the remote instance requires a signature to fetch the key...
  So if we're rejected, we should probably just give up.
  """
  def fetch_remote_key(key_id) do
    Logger.debug("Fetching remote key: #{key_id}")

    with {:ok, resp_body} <-
           Pleroma.Object.Fetcher.fetch_and_contain_remote_key(key_id),
         {:ok, ap_id, public_key_pem} <- handle_signature_response(resp_body),
         {:ok, user} <- User.get_or_fetch_by_ap_id(ap_id) do
      Logger.debug("Fetched remote key: #{ap_id}")
      # store the key
      key = %{
        user_id: user.id,
        public_key: public_key_pem,
        key_id: key_id
      }

      key_cs =
        cast(%__MODULE__{}, key, [:user_id, :public_key, :key_id])
        |> unique_constraint(:user_id)

      Repo.insert(key_cs,
        # while this should never run for local users anyway, etc make sure we really never loose privkey info!
        on_conflict: {:replace_all_except, [:inserted_at, :private_key]},
        # if the key owner overlaps with a distinct existing key entry, this intetionally still errros
        conflict_target: :key_id
      )
    else
      e ->
        Logger.debug("Failed to fetch remote key: #{inspect(e)}")
        {:error, "Could not fetch key"}
    end
  end

  defp refresh_key(%__MODULE__{} = key) do
    min_backoff = Pleroma.Config.get!([:activitypub, :min_key_refetch_interval])

    if Timex.diff(Timex.now(), key.updated_at, :seconds) >= min_backoff do
      fetch_remote_key(key.key_id)
    else
      {:error, :too_young}
    end
  end

  def refresh_by_key_id(key_id) do
    case Repo.get_by(__MODULE__, key_id: key_id) do
      nil -> {:error, :unknown}
      key -> refresh_key(key)
    end
  end

  # Take the response from the remote instance and extract the key details
  # will check if the key ID matches the owner of the key, if not, error
  defp extract_key_details(%{"id" => ap_id, "publicKey" => public_key}) do
    if ap_id !== public_key["owner"] do
      {:error, "Key ID does not match owner"}
    else
      %{"publicKeyPem" => public_key_pem} = public_key
      {:ok, ap_id, public_key_pem}
    end
  end

  defp handle_signature_response(body) do
    case body do
      %{
        "type" => "CryptographicKey",
        "publicKeyPem" => public_key_pem,
        "owner" => ap_id
      } ->
        {:ok, ap_id, public_key_pem}

      # for when we get a subset of the user object
      %{
        "id" => _user_id,
        "publicKey" => _public_key,
        "type" => actor_type
      }
      when actor_type in Pleroma.Constants.actor_types() ->
        extract_key_details(body)

      %{"error" => error} ->
        {:error, error}

      other ->
        {:error, "Could not process key: #{inspect(other)}"}
    end
  end
end
