defmodule ScriptureExtract do
  alias Exqlite.Sqlite3

  @moduledoc """
  Documentation for `ScriptureExtract`.
  """

  @doc """
  Extract the scriptures to markdown files which can be imported into any markdown supported system

  ## Examples

      iex> ScriptureExtract.run()

  """
  def run do
    db_location = Application.get_env(:scripture_extract, :db_location, "db")

    path = Path.expand("./#{db_location}")
    delete_output_directory()

    query_database(path)
    |> extract_striptures
  end

  def delete_output_directory() do
    output_dir = Application.get_env(:scripture_extract, :output_dir, "output")

    Path.expand("./#{output_dir}")
    |> File.rm_rf!()
  end

  def query_database(path) do
    {:ok, conn} = Sqlite3.open(path)

    {:ok, statement} =
      Sqlite3.prepare(
        conn,
        "select volume_id, book_id, chapter_id, verse_id, volume_title, book_title, chapter_number, verse_number, scripture_text
    from scriptures s"
      )

    {:ok, verse_data} = Sqlite3.fetch_all(conn, statement)
    verse_data
  end

  def get_book_subtitle(book_id) do
    db_location = Application.get_env(:scripture_extract, :db_location)
    path = Path.expand("./#{db_location}")

    {:ok, conn} = Sqlite3.open(path)
    {:ok, statement} = Sqlite3.prepare(conn, "select book_subtitle
    from books b
    where b.id = (?1) limit 1")
    Exqlite.Sqlite3.bind(conn, statement, [book_id])
    {:row, result} = Sqlite3.step(conn, statement)
    Enum.at(result, 0)
  end

  def get_all_book_data() do
    db_location = Application.get_env(:scripture_extract, :db_location)
    path = Path.expand("./#{db_location}")
    {:ok, conn} = Sqlite3.open(path)

    {:ok, statement} =
      Sqlite3.prepare(
        conn,
        "select book_id, count(chapter_number) as number_of_chapters
      from chapters c
      group by (book_id)"
      )

    {:ok, verse_data} = Sqlite3.fetch_all(conn, statement)
    verse_data
  end

  def extract_striptures(verse_data) do
    books_metadata =
      get_all_book_data()
      |> array_to_map

    Enum.each(verse_data, &extract_volume(&1, books_metadata))
  end

  def extract_volume(verse_data, books_metadata) do
    volume_title = get_verse_data_value(:volume_title, verse_data)
    output_dir = "./#{Application.get_env(:scripture_extract, :output_dir)}/#{volume_title}"

    Path.expand("#{output_dir}")
    |> File.mkdir_p!()

    chapter_number = get_verse_data_value(:chapter_number, verse_data)
    verse_number = get_verse_data_value(:verse_number, verse_data)
    write_to_volume_index(output_dir, verse_data, chapter_number, verse_number)
    extract_book(output_dir, books_metadata, verse_data)
  end

  ###############################################################

  def write_to_volume_index(output_dir, verse_data, _chapter_number = 1, _book_number = 1) do
    volume_title = get_verse_data_value(:volume_title, verse_data)
    book_title = get_verse_data_value(:book_title, verse_data)

    output_file = "#{output_dir}/#{volume_title}.md"

    {:ok, file} =
      Path.expand(output_file)
      |> File.open([:append])

    contents = "[[#{book_title}]]\n"
    IO.binwrite(file, contents)
    File.close(file)
  end

  def write_to_volume_index(_, _, _, _) do
  end

  ###############################################################
  def extract_book(output_dir, book_data, verse_data) do
    book_title = get_verse_data_value(:book_title, verse_data)

    output_dir = "#{output_dir}/#{book_title}"

    Path.expand("#{output_dir}")
    |> File.mkdir_p!()

    verse_number = get_verse_data_value(:verse_number, verse_data)
    write_to_book_index(output_dir, verse_data, verse_number)

    extract_chapter(output_dir, book_data, verse_data)
  end

  ###############################################################
  def write_to_book_index(output_dir, verse_data, 1) do
    book_title = get_verse_data_value(:book_title, verse_data)
    chapter_number = get_verse_data_value(:chapter_number, verse_data)

    output_file = "#{output_dir}/#{book_title}.md"

    {:ok, file} =
      Path.expand(output_file)
      |> File.open([:append])

    write_book_header(file, verse_data, chapter_number)

    contents = "[[#{book_title} #{chapter_number}]]\n"
    IO.binwrite(file, contents)
    File.close(file)
  end

  def write_to_book_index(_, _, _) do
  end

  ###############################################################
  def write_book_header(file, verse_data, 1) do
    book_id = get_verse_data_value(:book_id, verse_data)
    book_title = get_verse_data_value(:book_title, verse_data)

    subtitle = get_book_subtitle(book_id)
    volume_title = get_verse_data_value(:volume_title, verse_data)
    subtag = String.downcase(String.replace(volume_title, " ", "-"), :ascii)
    tag = "#scriptures/#{subtag}"

    contents = "# #{book_title}\n"
    contents = write_book_subtitle(contents, subtitle, tag)
    IO.binwrite(file, contents)
  end

  def write_book_header(_, _, _) do
  end

  def write_book_subtitle(contents, "", "") do
    "#{contents}\n"
  end

  def write_book_subtitle(contents, subtitle, "") do
    "#{contents}## #{subtitle}\n\n"
  end

  def write_book_subtitle(contents, subtitle, tag) do
    "#{contents}## #{subtitle}\n#{tag}\n\n"
  end

  ###############################################################
  def extract_chapter(output_dir, book_data, verse_data) do
    book_title = get_verse_data_value(:book_title, verse_data)
    chapter_number = get_verse_data_value(:chapter_number, verse_data)
    chapter_filename = get_chapter_filename(book_title, chapter_number)

    output_file = "#{output_dir}/#{chapter_filename}.md"

    {:ok, file} =
      Path.expand(output_file)
      |> File.open([:append])

    verse_number = get_verse_data_value(:verse_number, verse_data)
    write_chapter_header(file, book_data, verse_data, verse_number)

    verse_contents = extract_verse(verse_data)
    IO.binwrite(file, verse_contents)
    File.close(file)
  end

  def write_chapter_header(file, book_data, verse_data, 1) do
    file_metadata = get_chapter_metadata(verse_data, book_data)
    book_title = get_verse_data_value(:book_title, verse_data)
    chapter_number = get_verse_data_value(:chapter_number, verse_data)

    volume_title = get_verse_data_value(:volume_title, verse_data)
    subtag = String.downcase(String.replace(volume_title, " ", "-"), :ascii)

    IO.binwrite(
      file,
      "#{file_metadata}\n# #{book_title} #{chapter_number}\n#scriptures/#{subtag}\n\n"
    )
  end

  def write_chapter_header(_, _, _, _) do
  end

  def extract_verse(verse_data) do
    verse_number = get_verse_data_value(:verse_number, verse_data)
    scripture_text = get_verse_data_value(:scripture_text, verse_data)
    verse_reference = get_verse_reference(verse_data)
    "#{verse_number} #{scripture_text} ^#{verse_reference}\n\n"
  end

  defp get_chapter_metadata(verse_data, book_data) do
    chapter_number = get_verse_data_value(:chapter_number, verse_data)
    next_chapter_number = get_next_chapter_number(verse_data, book_data)

    previous_link = get_header_chapter_link(verse_data, chapter_number - 1)
    next_link = get_header_chapter_link(verse_data, next_chapter_number)
    "---\ntags: \n\t- scriptures\n---\n<< #{previous_link} | #{next_link} >>"
  end

  def get_next_chapter_number(verse_data, book_data) do
    book_id = get_verse_data_value(:book_id, verse_data)
    last_chapter = get_last_chapter_in_book(book_data, book_id)
    chapter_number = get_verse_data_value(:chapter_number, verse_data)

    if chapter_number === last_chapter,
      do: -1,
      else: chapter_number + 1
  end

  defp get_header_chapter_link(_, -1) do
    ""
  end

  defp get_header_chapter_link(_, 0) do
    ""
  end

  defp get_header_chapter_link(verse_data, chapter_number) do
    book_title = get_verse_data_value(:book_title, verse_data)
    get_chapter_link(book_title, chapter_number)
  end

  defp get_chapter_link(book_title, chapter_number) do
    chapter_filename = get_chapter_filename(book_title, chapter_number)
    "[[#{chapter_filename}]]"
  end

  defp get_chapter_filename(book_title, chapter_number) do
    "#{book_title} #{chapter_number}"
  end

  defp get_verse_data_value(:book_id, [_, book_id, _, _, _, _, _, _, _]) do
    book_id
  end

  defp get_verse_data_value(:volume_title, [_, _, _, _, volume_title, _, _, _, _]) do
    volume_title
  end

  defp get_verse_data_value(:book_title, [_, _, _, _, _, book_title, _, _, _]) do
    book_title
  end

  defp get_verse_data_value(:chapter_number, [_, _, _, _, _, _, chapter_number, _, _]) do
    chapter_number
  end

  defp get_verse_data_value(:verse_number, [_, _, _, _, _, _, _, verse_number, _]) do
    verse_number
  end

  defp get_verse_data_value(:scripture_text, [_, _, _, _, _, _, _, _, scripture_text]) do
    scripture_text
  end

  defp get_verse_reference([_, _, _, _, _, book_title, chapter_number, verse_number, _]) do
    "#{book_title}-#{chapter_number}-#{verse_number}"
    |> String.replace(" ", "")
    |> String.downcase(:ascii)
  end

  defp array_to_map(array) do
    list =
      array
      |> Enum.map(fn [book_id, chapter_count] ->
        book_key = String.to_atom("book_#{book_id}")
        %{book_key => chapter_count}
      end)

    Enum.reduce(list, &Map.merge/2)
  end

  defp get_last_chapter_in_book(book_data, book_id) do
    book_key = String.to_atom("book_#{book_id}")
    book_data[book_key]
  end
end
