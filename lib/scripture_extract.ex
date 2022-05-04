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
    db_location = Application.get_env(:scripture_extract, :db_location)

    path = Path.expand("./#{db_location}")
    delete_output_directory()

    query_database(path)
    |> extract_striptures
  end

  def delete_output_directory() do
    output_dir = Application.get_env(:scripture_extract, :output_dir)

    Path.expand("./#{output_dir}")
    |> File.rm_rf!
  end

  def query_database(path) do
    {:ok, conn} = Sqlite3.open(path)
    {:ok, statement} = Sqlite3.prepare(conn, "select volume_id, book_id, chapter_id, verse_id, volume_title, book_title, chapter_number, verse_number, scripture_text 
    from scriptures s")
    {:ok, result} = Sqlite3.fetch_all(conn, statement)
    result 
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

  def extract_striptures(result) do
    Enum.each(result, &extract_volume/1)    
  end

  def extract_volume(result) do
    volume_title = get_result_value(:volume_title, result)
    output_dir = "./#{Application.get_env(:scripture_extract, :output_dir)}/#{volume_title}"
    Path.expand("#{output_dir}")
    |> File.mkdir_p!

    chapter_number = get_result_value(:chapter_number, result)
    verse_number = get_result_value(:verse_number, result)
    write_to_volume_index(output_dir, result, chapter_number, verse_number)
    extract_book(output_dir, result)
  end
  ###############################################################

  def write_to_volume_index(output_dir, result, chapter_number = 1, book_number = 1) do
    volume_title = get_result_value(:volume_title, result)
    book_title = get_result_value(:book_title, result)

    output_file = "#{output_dir}/#{volume_title}.md"
    {:ok, file} = Path.expand(output_file)
    |> File.open([:append])

    contents = "[[#{book_title}]]\n"
    IO.binwrite(file, contents)
    File.close(file)
  end

  def write_to_volume_index(_, _, _, _) do end


  ###############################################################
  def extract_book(output_dir, result) do
    book_title = get_result_value(:book_title, result)

    output_dir = "#{output_dir}/#{book_title}"
    Path.expand("#{output_dir}")
    |> File.mkdir_p!

    verse_number = get_result_value(:verse_number, result)
    write_to_book_index(output_dir, result, verse_number)

    extract_chapter(output_dir, result)
  end

  ###############################################################
  def write_to_book_index(output_dir, result, 1) do
    book_title = get_result_value(:book_title, result)
    chapter_number = get_result_value(:chapter_number, result)

    output_file = "#{output_dir}/#{book_title}.md"
    {:ok, file} = Path.expand(output_file)
    |> File.open([:append])

    write_book_header(file, result, chapter_number)

    contents = "[[#{book_title} #{chapter_number}]]\n"
    IO.binwrite(file, contents)
    File.close(file)
  end

  def write_to_book_index(_, _, _) do end

  ###############################################################
  def write_book_header(file, result, 1) do
    book_id = get_result_value(:book_id, result)
    book_title = get_result_value(:book_title, result)

    subtitle = get_book_subtitle(book_id)
    volume_title = get_result_value(:volume_title, result)
    subtag = String.downcase(String.replace(volume_title, " ", "-"), :ascii)

    contents = "# #{book_title}\n#scriptures/#{subtag}\n"
    contents = write_book_subtitle(contents, subtitle)
    IO.binwrite(file, contents)
  end

  def write_book_header(_, _, _) do end

  def write_book_subtitle(contents, "") do
    "#{contents}\n"
  end

  def write_book_subtitle(contents, subtitle) do
    "#{contents}## #{subtitle}\n\n"
  end
    
  ###############################################################
  def extract_chapter(output_dir, result) do
    book_title = get_result_value(:book_title, result)
    chapter_number = get_result_value(:chapter_number, result)
  
    output_file = "#{output_dir}/#{book_title} #{chapter_number}.md"
    {:ok, file} = Path.expand(output_file)
    |> File.open([:append])

    verse_number = get_result_value(:verse_number, result)
    write_chapter_header(file, result, verse_number)

    verse_contents = extract_verse(result)
    IO.binwrite(file, verse_contents)
    File.close(file)
  end

  def write_chapter_header(file, result, 1) do
    book_title = get_result_value(:book_title, result)
    chapter_number = get_result_value(:chapter_number, result)

    volume_title = get_result_value(:volume_title, result)
    subtag = String.downcase(String.replace(volume_title, " ", "-"), :ascii)

    IO.binwrite(file, "# #{book_title} #{chapter_number}\n#scriptures/#{subtag}\n\n")
  end

  def write_chapter_header(_, _, _) do end

  def extract_verse(result) do
    verse_number = get_result_value(:verse_number, result)
    scripture_text = get_result_value(:scripture_text, result)
    "#{verse_number} #{scripture_text} ^#{verse_number}\n\n"
  end

  defp get_result_value(:book_id, [_, book_id, _, _, _, _, _, _, _]) do
    book_id
  end

  defp get_result_value(:volume_title, [_, _, _, _, volume_title, _, _, _, _]) do
    volume_title
  end

  defp get_result_value(:book_title, [_, _, _, _, _, book_title, _, _, _]) do
    book_title
  end

  defp get_result_value(:chapter_number, [_, _, _, _, _, _, chapter_number, _, _]) do
    chapter_number
  end

  defp get_result_value(:verse_number, [_, _, _, _, _, _, _, verse_number, _]) do
    verse_number
  end

  defp get_result_value(:scripture_text, [_, _, _, _, _, _, _, _, scripture_text]) do
    scripture_text
  end
end
