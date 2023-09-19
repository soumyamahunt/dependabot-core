# typed: false
# frozen_string_literal: true

################################################################################
# For more details on Go version constraints, see:                             #
# - https://github.com/Masterminds/semver                                      #
# - https://github.com/golang/dep/blob/master/docs/Gopkg.toml.md               #
################################################################################

require "dependabot/utils"
require "dependabot/go_modules/version"

module Dependabot
  module GoModules
    class Requirement < Gem::Requirement
      WILDCARD_REGEX = /(?:\.|^)[xX*]/
      OR_SEPARATOR = /(?<=[a-zA-Z0-9*])\s*\|{2}/

      # Override the version pattern to allow a 'v' prefix
      quoted = OPS.keys.map { |k| Regexp.quote(k) }.join("|")
      version_pattern = "v?#{Version::VERSION_PATTERN}"

      PATTERN_RAW = "\\s*(#{quoted})?\\s*(#{version_pattern})\\s*".freeze
      PATTERN = /\A#{PATTERN_RAW}\z/

      # Use GoModules::Version rather than Gem::Version to ensure that
      # pre-release versions aren't transformed.
      def self.parse(obj)
        return ["=", Version.new(obj.to_s)] if obj.is_a?(Gem::Version)

        unless (matches = PATTERN.match(obj.to_s))
          msg = "Illformed requirement [#{obj.inspect}]"
          raise BadRequirementError, msg
        end

        return DefaultRequirement if matches[1] == ">=" && matches[2] == "0"

        [matches[1] || "=", Version.new(matches[2])]
      end

      # Returns an array of requirements. At least one requirement from the
      # returned array must be satisfied for a version to be valid.
      def self.requirements_array(requirement_string)
        return [new(nil)] if requirement_string.nil?

        requirement_string.strip.split(OR_SEPARATOR).map do |req_string|
          new(req_string)
        end
      end

      def initialize(*requirements)
        requirements = requirements.flatten.flat_map do |req_string|
          req_string.split(",").map(&:strip).map do |r|
            convert_go_constraint_to_ruby_constraint(r.strip)
          end
        end

        super(requirements)
      end

      private

      def convert_go_constraint_to_ruby_constraint(req_string)
        req_string = convert_wildcard_characters(req_string)

        if req_string.match?(WILDCARD_REGEX)
          ruby_range(req_string.gsub(WILDCARD_REGEX, "").gsub(/^[^\d]/, ""))
        elsif req_string.match?(/^~[^>]/) then convert_tilde_req(req_string)
        elsif req_string.include?(" - ") then convert_hyphen_req(req_string)
        elsif req_string.match?(/^[\dv^]/) then convert_caret_req(req_string)
        elsif req_string.match?(/[<=>]/) then req_string
        else
          ruby_range(req_string)
        end
      end

      def convert_wildcard_characters(req_string)
        if req_string.match?(/^[\dv^>~]/)
          replace_wildcard_in_lower_bound(req_string)
        elsif req_string.start_with?("<")
          parts = req_string.split(".")
          parts.map.with_index do |part, index|
            next "0" if part.match?(WILDCARD_REGEX)
            next part.to_i + 1 if parts[index + 1]&.match?(WILDCARD_REGEX)

            part
          end.join(".")
        else
          req_string
        end
      end

      def replace_wildcard_in_lower_bound(req_string)
        after_wildcard = false

        req_string = req_string.gsub(/(?:(?:\.|^)[xX*])(\.[xX*])+/, "") if req_string.start_with?("~")

        req_string.split(".")
                  .map do |part|
          part.split("-").map.with_index do |p, i|
            # Before we hit a wildcard we just return the existing part
            next p unless p.match?(WILDCARD_REGEX) || after_wildcard

            # On or after a wildcard we replace the version part with zero
            after_wildcard = true
            i.zero? ? "0" : "a"
          end.join("-")
        end.join(".")
      end

      def convert_tilde_req(req_string)
        version = req_string.gsub(/^~/, "")
        parts = version.split(".")
        parts << "0" if parts.count < 3
        "~> #{parts.join('.')}"
      end

      def convert_hyphen_req(req_string)
        lower_bound, upper_bound = req_string.split(/\s+-\s+/)
        [">= #{lower_bound}", "<= #{upper_bound}"]
      end

      def ruby_range(req_string)
        parts = req_string.split(".")

        # If we have three or more parts then this is an exact match
        return req_string if parts.count >= 3

        # If we have no parts then the version is completely unlocked
        return ">= 0" if parts.count.zero?

        # If we have fewer than three parts we do a partial match
        parts << "0"
        "~> #{parts.join('.')}"
      end

      # NOTE: Dep's caret notation implementation doesn't distinguish between
      # pre and post-1.0.0 requirements (unlike in JS)
      def convert_caret_req(req_string)
        version = req_string.gsub(/^\^?v?/, "")
        parts = version.split(".")
        upper_bound = [parts.first.to_i + 1, 0, 0, "a"].map(&:to_s).join(".")

        [">= #{version}", "< #{upper_bound}"]
      end
    end
  end
end

Dependabot::Utils
  .register_requirement_class("go_modules", Dependabot::GoModules::Requirement)
