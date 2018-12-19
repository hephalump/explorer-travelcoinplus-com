defmodule BlockScoutWeb.AddressChannelTest do
  use BlockScoutWeb.ChannelCase

  alias BlockScoutWeb.Notifier

  test "subscribed user is notified of new_address count event" do
    topic = "addresses:new_address"
    @endpoint.subscribe(topic)

    address = insert(:address)

    Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "count", payload: %{count: _}}, 5_000
  end

  describe "user subscribed to address" do
    setup do
      address = insert(:address)
      topic = "addresses:#{address.hash}"
      @endpoint.subscribe(topic)
      {:ok, %{address: address, topic: topic}}
    end

    test "notified of balance_update for matching address", %{address: address, topic: topic} do
      address_with_balance = %{address | fetched_coin_balance: 1}
      Notifier.handle_event({:chain_event, :addresses, :realtime, [address_with_balance]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "balance_update", payload: payload}, 5_000
      assert payload.address.hash == address_with_balance.hash
    end

    test "not notified of balance_update if fetched_coin_balance is nil", %{address: address} do
      Notifier.handle_event({:chain_event, :addresses, :realtime, [address]})

      refute_receive _, 100, "Message was broadcast for nil fetched_coin_balance."
    end

    test "notified of new_pending_transaction for matching from_address", %{address: address, topic: topic} do
      pending = insert(:transaction, from_address: address)

      Notifier.handle_event({:chain_event, :transactions, :realtime, [pending.hash]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "pending_transaction", payload: payload}, 5_000
      assert payload.address.hash == address.hash
      assert payload.transaction.hash == pending.hash
    end

    test "notified of new_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction.hash]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload}, 5_000
      assert payload.address.hash == address.hash
      assert payload.transaction.hash == transaction.hash
    end

    test "notified of new_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction.hash]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload}, 5_000
      assert payload.address.hash == address.hash
      assert payload.transaction.hash == transaction.hash
    end

    test "not notified twice of new_transaction if to and from address are equal", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      Notifier.handle_event({:chain_event, :transactions, :realtime, [transaction.hash]})

      assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "transaction", payload: payload}, 5_000
      assert payload.address.hash == address.hash
      assert payload.transaction.hash == transaction.hash

      refute_receive _, 100, "Received duplicate broadcast."
    end

    test "notified of new_internal_transaction for matching from_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(from_address: address)
        |> with_block()

      internal_transaction = insert(:internal_transaction, transaction: transaction, from_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [internal_transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "internal_transaction",
                       payload: %{
                         address: %{hash: address_hash},
                         internal_transaction: %{transaction_hash: transaction_hash, index: index}
                       }
                     },
                     5_000

      assert address_hash == address.hash
      assert {transaction_hash, index} == {internal_transaction.transaction_hash, internal_transaction.index}
    end

    test "notified of new_internal_transaction for matching to_address", %{address: address, topic: topic} do
      transaction =
        :transaction
        |> insert(to_address: address)
        |> with_block()

      internal_transaction = insert(:internal_transaction, transaction: transaction, to_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [internal_transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "internal_transaction",
                       payload: %{
                         address: %{hash: address_hash},
                         internal_transaction: %{transaction_hash: transaction_hash, index: index}
                       }
                     },
                     5_000

      assert address_hash == address.hash
      assert {transaction_hash, index} == {internal_transaction.transaction_hash, internal_transaction.index}
    end

    test "not notified twice of new_internal_transaction if to and from address are equal", %{
      address: address,
      topic: topic
    } do
      transaction =
        :transaction
        |> insert(from_address: address, to_address: address)
        |> with_block()

      internal_transaction =
        insert(:internal_transaction, transaction: transaction, from_address: address, to_address: address, index: 0)

      Notifier.handle_event({:chain_event, :internal_transactions, :realtime, [internal_transaction]})

      assert_receive %Phoenix.Socket.Broadcast{
                       topic: ^topic,
                       event: "internal_transaction",
                       payload: %{
                         address: %{hash: address_hash},
                         internal_transaction: %{transaction_hash: transaction_hash, index: index}
                       }
                     },
                     5_000

      assert address_hash == address.hash
      assert {transaction_hash, index} == {internal_transaction.transaction_hash, internal_transaction.index}

      refute_receive _, 100, "Received duplicate broadcast."
    end
  end
end