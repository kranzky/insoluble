#!/usr/bin/env ruby

require 'amazing_print'
require 'byebug'
require 'ruby-progressbar'
require 'openai'
require 'json'

OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_SECRET_KEY")
end

client = OpenAI::Client.new

message = "Lorenz attractor symbolizing multiple universes with an author on one side and a reader on the other."

response = client.images.generate(parameters: { prompt: message, size: "1024x1024" })

ap response

response.dig("choices", 0, "message", "content")
