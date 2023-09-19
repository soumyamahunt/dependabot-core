# typed: true
# frozen_string_literal: true

require "dependabot/metadata_finders"
require "dependabot/metadata_finders/base"

module Dependabot
  module GitSubmodules
    class MetadataFinder < Dependabot::MetadataFinders::Base
      private

      def look_up_source
        url = dependency.requirements.first.fetch(:source)[:url] ||
              dependency.requirements.first.fetch(:source).fetch("url")

        Source.from_url(url)
      end
    end
  end
end

Dependabot::MetadataFinders
  .register("submodules", Dependabot::GitSubmodules::MetadataFinder)
