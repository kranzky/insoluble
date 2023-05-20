#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

#===============================================================================

def get_response(prompt)
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
    config.request_timeout = 300
  end
  client = OpenAI::Client.new
  request =
    {
      model: "gpt-4",
      temperature: 0.7,
      messages: prompt.split("\n").map do |message|
        {
          role: "user",
          content: message
        }
      end
    }
  response = client.chat(parameters: request)
  result = response.dig("choices", 0, "message", "content")
  raise "no response" if result.nil?
  result
end

#-------------------------------------------------------------------------------

def generate_prologue_summary
  return if $book[:prologue][:summary]
  puts "Generating prologue summary..."
  prompt = <<~PROMPT
    We are writing a novel together. Here is the prologue that you wrote for it:
    
    #{$book[:prologue][:paragraphs].join("\n\n")}

    Write a single paragraph which summarises this prologue.
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
    chapter[:context] = "This is the first chapter of the novel."
  else
    prompt = <<~PROMPT
      We are writing a novel together. We are about to start writing a new chapter. Here is what has happened in the previous chapters:
      #{summaries.join("\n")}
      
      Write a single paragraph which summarises what has happened in the novel so far.
    PROMPT
    debugger
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
  prev_chapter =
    if $book[:state][:chapter][:index] == 0
      {
        prompt: "There was no previous chapter! This is the first chapter of the novel, so please take your time and make sure to set things up slowly."
      }      
    else
      $book[:chapters][$book[:state][:chapter][:index]-1]
    end
  next_chapter =
    if $book[:state][:chapter][:index] == $book[:chapters].count-1
      {
        prompt: "There is no next chapter! This is the last chapter of the novel, so please make sure to wrap things up with a bang!"
      }
    else
      $book[:chapters][$book[:state][:chapter][:index]+1]
    end
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    Here is a list of characters:
    #{characters}

    Here is a list of locations:
    #{locations}

    #{chapter[:context]}

    We are about to write a new chapter. Here's what needs to happen in this chapter: #{chapter[:prompt]}
    
    Here's what happened in the previous chapter: #{prev_chapter[:prompt]}

    And here's what will happen in the next chapter: #{next_chapter[:prompt]}
    
    Bearing in mind the rules of narrative, and making sure to be consistent with the story so far, write a list of scenes which will make up this chapter. More scenes are better than fewer scenes. Make sure to resolve any loose ends from the previous chapter, and set things up for the next chapter without pre-empting anything that happens in the next chapter. Create a cliffhanger at the end of this chapter if possible. The list of scenes should be presented a JSON array of objects, with each object containing name and prompt keys.
  PROMPT
  chapter[:scenes] = JSON.parse(get_response(prompt))
  $book[:state][:changed] = true
ensure
  $book[:state][:chapter][:name] = "scene"
  $book[:state][:scene][:name] = "context"
  $book[:state][:scene][:index] = 0
end

#-------------------------------------------------------------------------------

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
    scene[:context] = "This is the first scene of the chapter."
  else
    prompt = <<~PROMPT
      We are writing a novel together. We are currently writing a chapter in the novel. We are about to write a new scene in the chapter. Here's what has happened in the previous scenes:
      #{summaries.join("\n")}
      
      Write a single paragraph which summarises what has happened in the chapter so far.
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
  prompt = <<~PROMPT
    We are writing a novel together. #{$book[:genre]}
    
    Here is a list of characters:
    #{characters}

    Here is a list of locations:
    #{locations}

    We are currently writing a chapter in the novel. Here is what has happened in the chapter so far: #{scene[:context]}

    We are about to write a scene. Here's what needs to happen in this scene: #{scene[:prompt]}
    
    Bearing in mind the rules of narrative, and making sure to be consistent with what has happened in the chapter so far, write a list of story beats which will make up this scene. More story beats are better than fewer story beats. The list of story beats should be presented a JSON array of objects, with each object containing name and prompt keys.
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
    
    Here is a list of characters:
    #{characters}

    Here is a list of locations:
    #{locations}

    We are currently writing a scene in a chapter of the novel. Here's what happens in this scene: #{scene[:prompt]}
    
    Here are the story beats that make up this scene:
    #{scene[:beats].map { |beat| "#{beat[:name]}: #{beat[:prompt]}" }.join("\n")}

    Write the full text of this scene using these story beats as a guideline. The scene should be a few pages long. Please write lengthy, descriptive paragraphs and compelling dialogue between characters. Introduce new minor characters if you like, and create dramatic tension where possible. The scene should be presented as a JSON array of strings, with each string making up a paragraph of text.
  PROMPT
  scene[:text] = JSON.parse(get_response(prompt))
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
    We are writing a novel together. Here is a scene within a chapter:
    #{scene[:text].join("\n")}

    Write a single paragraph which summarises this scene.
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