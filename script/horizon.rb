#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

#===============================================================================

def get_response(prompt)
  puts prompt
  debugger
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
    config.request_timeout = 300
  end
  client = OpenAI::Client.new
  request =
    {
      model: "gpt-4",
      temperature: 0.7,
      messages: [{ role: "user", content: prompt }]
    }
  response = client.chat(parameters: request)
  result = response.dig("choices", 0, "message", "content")
  raise "no response" if result.nil?
  puts result
  result
end

#-------------------------------------------------------------------------------

def generate_prologue_summary
  return if $book[:prologue][:summary]
  puts "Generating prologue summary..."
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}

    Here is the prologue to the novel:

    #{$book[:prologue][:paragraphs].join("\n\n")}

    Write a single paragraph which briefly summarises this prologue. Be concise and don't preface your summary by mentioning story or chapter or scene.
  PROMPT
  $book[:prologue][:summary] = get_response(prompt)
  $book[:state][:changed] = true
ensure
  $book[:state][:name] = "chapters"
  $book[:state][:chapter][:name] = "context"
  $book[:state][:chapter][:index] = 0
end

#-------------------------------------------------------------------------------

def generate_chapters
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  case $book[:state][:chapter][:name]
  when "context"
    generate_chapter_context
  when "scenes"
    generate_scenes
  when "scene"
    generate_scene
  when "summary"
    raise "not implemented"
  end
end

#-------------------------------------------------------------------------------

def generate_chapter_context
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  return if chapter[:context]
  puts "Generating chapter context..."
  summaries = $book[:chapters].map { |c| c[:summary] }.compact
  if summaries.empty?
    chapter[:context] = "We are just beginning to write the novel, so please take some time establishing the main characters and the first location."
  else
    prompt = <<~PROMPT
      We are writing a novel together. #{$book[:genre]}

      Here is what has happened in the previous chapters:

      #{summaries.join("\n\n")}
      
      Write a single paragraph which briefly summarises what has happened in the novel so far. Be concise and don't preface your summary by mentioning story or chapter or scene.
    PROMPT
    chapter[:context] = get_response(prompt)
  end
  $book[:state][:changed] = true
ensure
  $book[:state][:chapter][:name] = "scenes"
end

#-------------------------------------------------------------------------------

def generate_scenes
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  return if chapter[:scenes]
  puts "Generating chapter scenes..."
  next_chapter =
    if $book[:state][:chapter][:index] == $book[:chapters].count-1
      {
        prompt: "This is the last chapter of the novel."
      }
    else
      $book[:chapters][$book[:state][:chapter][:index]+1]
    end
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    These are the major characters in the story:
    #{characters}

    And these are the main locations that the story takes place in:
    #{locations}

    We are about to start a new chapter. Here's what has happened in the story so far: #{chapter[:context]}

    Here is what will happen in the chapter following the one you are about to write: #{next_chapter[:prompt]}

    And here is a description of what needs to happen in this chapter: #{chapter[:prompt]}
    
    Bearing in mind the rules of narrative, and making sure to be consistent with the genre and what has happened in the story so far, write a list of scenes which will make up this chapter. More scenes are better than fewer scenes. Make sure to cover only what needs to happen in this chapter, and stop before you reach anything that occurs in the next chapter. Create a cliffhanger at the end of this chapter if possible. The list of scenes should be presented a JSON array of objects, with each object containing name and prompt keys.
  PROMPT
  chapter[:scenes] = JSON.parse(get_response(prompt))
  $book[:state][:changed] = true
ensure
  $book[:state][:chapter][:name] = "scene"
  $book[:state][:scene][:name] = "context"
  $book[:state][:scene][:index] = 0
end

#------------------------------------------the genre and -------------------------------------

def characters
  $book[:characters].map do |character|
    "#{character[:name]}: #{character[:description]}"
  end.join("\n")
end

#-------------------------------------------------------------------------------

def locations
  $book[:locations].map do |locations|
    "#{locations[:name]}: #{locations[:description]}"
  end.join("\n")
end

#-------------------------------------------------------------------------------

def generate_scene_context
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  return if scene[:context]
  puts "Generating scene context..."
  summaries = chapter[:scenes].map { |scene| scene[:summary] }.compact
  if summaries.empty?
    scene[:context] = "We are just beginning to write the chapter."
  else
    prompt = <<~PROMPT
      We are writing a novel together. #{$book[:genre]}

      Here's a summary of the scenes that we have written in the current chapter:

      #{summaries.join("\n\n")}
      
      Write a single paragraph which briefly summarises what has happened in the chapter so far. Be concise and don't preface your summary by mentioning story or chapter or scene.
    PROMPT
    scene[:context] = get_response(prompt)
  end
  $book[:state][:changed] = true
ensure
  $book[:state][:scene][:name] = "beats"
end

#-------------------------------------------------------------------------------

def generate_scene_beats
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  return if scene[:beats]
  puts "Generating scene beats..."
  next_scene =
    if $book[:state][:scene][:index] == chapter[:scenes].count-1
      {
        prompt: "This is the last scene of the chapter."
      }
    else
      chapter[:scenes][$book[:state][:scene][:index]+1]
    end
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    These are the major characters in the story:
    #{characters}

    And these are the main locations that the story takes place in:
    #{locations}

    We are about to write a scene within a chapter. Here is what has happened in the chapter so far: #{scene[:context]}

    Here is what will happen in the scene following the one you are about to write: #{next_scene[:prompt]}

    And here is a description of what needs to happen in this scene: #{scene[:prompt]}
    
    Bearing in mind the rules of narrative, and making sure to be consistent with the genre and what has happened in the chapter so far, write a list of story beats which will make up this scene. More story beats are better than fewer story beats. Make sure to cover only what needs to happen in this scene, and stop before you reach anything that occurs in the next scene. The list of story beats should be presented a JSON array of objects, with each object containing name and prompt keys.
  PROMPT
  scene[:beats] = JSON.parse(get_response(prompt))
  $book[:state][:changed] = true
ensure
  $book[:state][:scene][:name] = "text"
end

#-------------------------------------------------------------------------------

def generate_scene_text
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  return if scene[:text]
  puts "Generating scene text..."
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    These are the major characters in the story:
    #{characters}

    And these are the main locations that the story takes place in:
    #{locations}

    We are currently writing a scene in a chapter of the novel. Here's a description of what needs to happen in this scene: #{scene[:prompt]}
    
    Here are the story beats that make up this scene:
    #{scene[:beats].map { |beat| "#{beat[:name]}: #{beat[:prompt]}" }.join("\n")}

    Write the full text of this scene using these story beats as a guideline, making sure to stay true to the genre. The scene should be at least a few pages long. Please write lengthy, descriptive paragraphs and compelling dialogue between characters. Introduce new minor characters if you like, and create dramatic tension where possible. Your response should be formatted suitable for printing in a book, but please omit chapter and section headings, and don't mention story, chapter, scene or beat.
  PROMPT
  scene[:text] = get_response(prompt)
  $book[:state][:changed] = true
ensure
  $book[:state][:scene][:name] = "summary"
end

#-------------------------------------------------------------------------------

def generate_scene_summary
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  return if scene[:summary]
  puts "Generating scene summary..."
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    Here is a scene taken from a chapter of the novel:

    #{scene[:text]}

    Write a single paragraph which briefly summarises this scene. Be concise and don't preface your summary by mentioning story or chapter or scene.
  PROMPT
  scene[:summary] = get_response(prompt)
  $book[:state][:changed] = true
ensure
  if $book[:state][:scene][:index] < chapter[:scenes].count-1
    $book[:state][:scene][:name] = "context"
    $book[:state][:scene][:index] += 1
  else
    $book[:state][:chapter][:name] = "summary"
  end
end

#-------------------------------------------------------------------------------

def generate_scene
  chapter = $book[:chapters][$book[:state][:chapter][:index]]
  scene = chapter[:scenes][$book[:state][:scene][:index]]
  case $book[:state][:scene][:name]
  when "context"
    generate_scene_context
  when "beats"
    generate_scene_beats
  when "text"
    generate_scene_text
  when "summary"
    generate_scene_summary
  end
end

#===============================================================================

$book = JSON.parse(File.read("horizon.json"), symbolize_names: true)
$book[:state][:changed] = false

while !$book[:state][:changed]
  case $book[:state][:name]
  when "prologue"
    generate_prologue_summary
  when "chapters"
    generate_chapters
  when "epilogue"
    raise "not implemented"
  else
    raise "unknown state" 
  end
end

File.write("horizon.json", JSON.pretty_generate($book))