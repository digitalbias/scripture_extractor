import Config

if Config.config_env() == :dev do
    DotenvParser.load_file(".env")
end

config :scripture_extract,
  db_location: System.fetch_env!("DB_LOCATION"),
  output_dir: System.fetch_env!("OUTPUT_DIR")