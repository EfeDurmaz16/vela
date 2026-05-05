defmodule Vela.Storage.S3ObjectStore do
  @moduledoc """
  S3-compatible object store using AWS Signature Version 4.
  """

  @behaviour Vela.Storage.ObjectStore
  @service "s3"
  @algorithm "AWS4-HMAC-SHA256"

  @impl Vela.Storage.ObjectStore
  def put_object(attrs) do
    request(:put, attrs, Map.fetch!(attrs, :body))
  end

  @impl Vela.Storage.ObjectStore
  def get_object(attrs) do
    with {:ok, %{body: body}} <- request(:get, attrs, nil), do: {:ok, body}
  end

  @impl Vela.Storage.ObjectStore
  def presign_get(attrs), do: presign(:get, attrs)

  defp request(method, attrs, body) do
    now = Map.get(attrs, :now, DateTime.utc_now())
    uri = object_uri(attrs)
    payload_hash = sha256_hex(body || "")
    headers = signed_headers(method, uri, attrs, payload_hash, now)

    [
      method: method,
      url: URI.to_string(uri),
      headers: headers,
      body: body,
      transport: Map.get(attrs, :transport)
    ]
    |> Vela.HTTP.request()
    |> handle_response()
  end

  defp presign(:get, attrs) do
    now = Map.get(attrs, :now, DateTime.utc_now())
    uri = object_uri(attrs)
    amz_date = amz_date(now)
    scope = credential_scope(attrs, now)

    query = %{
      "X-Amz-Algorithm" => @algorithm,
      "X-Amz-Credential" => "#{Map.fetch!(attrs, :access_key_id)}/#{scope}",
      "X-Amz-Date" => amz_date,
      "X-Amz-Expires" => to_string(Map.get(attrs, :expires_in, 300)),
      "X-Amz-SignedHeaders" => "host"
    }

    canonical =
      canonical_request("GET", uri.path, query, "host:#{uri.host}\n", "host", "UNSIGNED-PAYLOAD")

    string_to_sign = string_to_sign(canonical, amz_date, scope)
    signature = signing_key(attrs, now) |> hmac_hex(string_to_sign)

    {:ok, %{uri | query: URI.encode_query(Map.put(query, "X-Amz-Signature", signature))}}
  end

  defp signed_headers(method, uri, attrs, payload_hash, now) do
    amz_date = amz_date(now)
    scope = credential_scope(attrs, now)

    canonical_headers =
      "host:#{uri.host}\nx-amz-content-sha256:#{payload_hash}\nx-amz-date:#{amz_date}\n"

    signed_headers = "host;x-amz-content-sha256;x-amz-date"

    canonical =
      canonical_request(
        method |> to_string() |> String.upcase(),
        uri.path,
        %{},
        canonical_headers,
        signed_headers,
        payload_hash
      )

    signature = attrs |> signing_key(now) |> hmac_hex(string_to_sign(canonical, amz_date, scope))

    [
      {"host", uri.host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date},
      {"authorization",
       "#{@algorithm} Credential=#{Map.fetch!(attrs, :access_key_id)}/#{scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"}
    ]
  end

  defp object_uri(attrs) do
    endpoint = attrs |> Map.fetch!(:endpoint) |> String.trim_trailing("/")
    bucket = Map.fetch!(attrs, :bucket)
    key = attrs |> Map.fetch!(:key) |> encode_key()
    URI.parse("#{endpoint}/#{bucket}/#{key}")
  end

  defp encode_key(key),
    do:
      key
      |> String.split("/")
      |> Enum.map_join("/", fn part -> URI.encode(part, &URI.char_unreserved?/1) end)

  defp canonical_request(method, path, query, canonical_headers, signed_headers, payload_hash) do
    [method, path, canonical_query(query), canonical_headers, signed_headers, payload_hash]
    |> Enum.join("\n")
  end

  defp canonical_query(query) do
    query
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map_join("&", fn {key, value} ->
      URI.encode(to_string(key)) <> "=" <> URI.encode(to_string(value))
    end)
  end

  defp string_to_sign(canonical_request, amz_date, scope) do
    [@algorithm, amz_date, scope, sha256_hex(canonical_request)] |> Enum.join("\n")
  end

  defp credential_scope(attrs, now),
    do: "#{date_stamp(now)}/#{Map.fetch!(attrs, :region)}/#{@service}/aws4_request"

  defp signing_key(attrs, now),
    do:
      hmac("AWS4" <> Map.fetch!(attrs, :secret_access_key), date_stamp(now))
      |> hmac(Map.fetch!(attrs, :region))
      |> hmac(@service)
      |> hmac("aws4_request")

  defp amz_date(now), do: Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
  defp date_stamp(now), do: Calendar.strftime(now, "%Y%m%d")
  defp sha256_hex(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp hmac(key, value), do: :crypto.mac(:hmac, :sha256, key, value)
  defp hmac_hex(key, value), do: hmac(key, value) |> Base.encode16(case: :lower)

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299,
    do: {:ok, response}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {:s3_error, status, body}}

  defp handle_response({:error, reason}), do: {:error, reason}
end
