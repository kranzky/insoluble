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

message = "Cover image for a sci-fi romance novel showing a futuristic starship in space near a nebula, with abstract silhouettes of a human woman and an alien man symbolizing a romantic connection."

response = client.images.generate(parameters: { prompt: message, size: "1024x1024" })

ap response

response.dig("choices", 0, "message", "content")
