# frozen_string_literal: true

Pagy::OPTIONS[:limit] = 10               # Limit the items per page
Pagy::OPTIONS[:client_max_limit] = 10    # The client can request a limit up to 100
Pagy::OPTIONS.freeze
