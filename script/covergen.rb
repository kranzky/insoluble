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

message = "Albert Einstein and Tony Abbott fighting over a Nintendo Switch in a photo realistic style."

response = client.images.generate(parameters: { prompt: message, size: "1024x1024" })

ap response

response.dig("choices", 0, "message", "content")
