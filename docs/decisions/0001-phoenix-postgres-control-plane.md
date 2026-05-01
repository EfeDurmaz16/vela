# 0001: Phoenix and Postgres Control Plane

Vela uses Phoenix LiveView for the initial application shell and Postgres as the canonical database. This keeps realtime UI, durable state and Ecto schemas in one coherent foundation before Rust and Python services are split out.
