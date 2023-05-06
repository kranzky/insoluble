#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

def get_response(prompt)
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
  end

  client = OpenAI::Client.new

  ap prompt

  response =
    client.chat(
      parameters: {
        model: "gpt-4",
        temperature: 0.7,
        messages: prompt.map do |content|
          {
            role: "user",
            content: content
          }
        end
      }
    )

  ap response

  response.dig("choices", 0, "message", "content")
end

book = JSON.parse(File.read("book.json"), symbolize_names: true)

prompt = [DATA.read.gsub(/TITLE/, book[:title]).gsub(/AUTHOR/, book[:author]).strip]

unless book[:summary].empty?
  prompt << "We have already been writing this book together in other sessions. Here is what you previously said when I asked you to summarise what you had written so far: #{book[:summary]}"
end

chapter_count = book[:chapters].count
book[:chapters].each.with_index do |chapter, chapter_index|
  section_count = chapter[:sections].count
  chapter[:sections].each.with_index do |section, section_index|
    paragraph_count = section[:templates].count
    next if paragraph_count == section[:generated].count
    section[:templates].each.with_index do |template, paragraph_index|
      next unless section[:generated][paragraph_index].nil?
      prompt << "Here's the template for paragraph #{paragraph_index+1} of #{paragraph_count} in section #{section_index+1} of #{section_count} in chapter #{chapter_index+1} of #{chapter_count}, which is named \"#{chapter[:name]}\", and which should be written in #{chapter[:mode]}:"
      response = get_response([prompt.join(" "), ""] + template)
      exit if response.nil?
      sleep 15
      summary = get_response(["Briefly summarise what we've achieved so far, in a single paragraph, which I will use to continue this writing session at another time. Include enough detail so that you will be able to continue from where you left off."])
      exit if summary.nil?
      section[:generated] << response
      book[:summary] = summary
      break
    end
    break
  end
  break
end

File.write("book.json", JSON.pretty_generate(book))

__END__
We are writing a book together. It is called "TITLE" and the author is "AUTHOR", but do not mention these or the chapter names in what you write. The protagonist is a man. I am going to give you a template for each paragraph in the book. Please use it to write a paragraph that contains one sentence for every line in the template. Each line of the template starts by indicating whether the sentence should be written as exposition or dialogue, followed by the number of words that should be in the sentence. After that is a list of capitalised keywords that should be in the sentence if possible, in any order, but you don't need to use all of them. Write the paragraph to be a consistent part of a larger story.
