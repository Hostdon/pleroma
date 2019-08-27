defmodule Pleroma.Web.ActivityPub.MRF.GABRewritePolicy do
  @moduledoc "Adds stupid quotes to gab users"
  @behaviour Pleroma.Web.ActivityPub.MRF
  @domain "gab.com"
  @appends [
    "Sent from AOL Mobile Mail",
    "John had surgery Friday and he's with the lord now.",
    "Lovely pics as alway, Janice. I have terminal brain cancer.",
    "DISCUSTING",
    "I DID NOT POST THAT! SOMEONE HAS HACKED MY ACCOUNT",
    "LOVE ETHYL",
    "Just got back from the doctor. I have Ebola. See you at church on Sunday!",
    "ADULT ONLY",
    "Are you my grandson?",
    "http://m.facebook.com",
    "WISH GOD WOULD TAKE ME.",
    "YOU SURE ARE A LONG BABY",
    "REFURBISHD +OK?",
    "THIS EMAIL IS INTENDED FOR THE RECIPIENT ONLY. PLEASE THINK ABOUT THE ENVIRONMENT BEFORE YOU PRINT THIS MESSAGE",
    "AC/DC is my favourite band",
    "BRAD'S WIFE!",
    "Order corn!",
    "Yim yum",
    "My 49 year old son, Shane, died this morning.",
    "I called Mr uber",
    "Coconut oil.",
    "price for apple sauce at walmart",
    "no SWEARING on my timeline!",
    "MILK TRUK JUST ARRIVE",
    "Also my catheter bag is full.",
    "Go finish your yoghurt",
    "I am going to slap your mouth grandson."
  ]

  def add(%{"object" => %{"content" => content}} = object) do
    put_in(object, ["object", "content"], content <> " " <> Enum.random(@appends))
  end

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def filter(%{"type" => "Create", "actor" => actor} = object) do
    actor_info = URI.parse(actor)
    if String.contains?(actor_info.host, @domain) do
      {:ok, add(object)}
    else
      {:ok, object}
    end
  end

  def filter(object), do: {:ok, object}
end
