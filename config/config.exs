# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# These are the primary varaibles which need to be set for each environment.
# config :scripture_extract, db_location: ""

# You can also configure a third-party app:
#
#     config :logger, level: :info
#

config :scripture_extract,
  db_location: System.get_env("DB_LOCATION"),
  output_dir: System.get_env("OUTPUT_DIR")
