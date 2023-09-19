# typed: true
# frozen_string_literal: true

require "dependabot/version"
require "dependabot/utils"

# JavaScript pre-release versions use 1.0.1-rc1 syntax, which Gem::Version
# converts into 1.0.1.pre.rc1. We override the `to_s` method to stop that
# alteration.
#
# See https://semver.org/ for details of node's version syntax.

module Dependabot
  module NpmAndYarn
    class Version < Dependabot::Version
      extend T::Sig

      sig { returns(String) }
      attr_reader :build_info

      VERSION_PATTERN = T.let(Gem::Version::VERSION_PATTERN + '(\+[0-9a-zA-Z\-.]+)?', String)
      ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})?\s*\z/

      sig { override.params(version: T.nilable(T.any(String, Gem::Version))).returns(T::Boolean) }
      def self.correct?(version)
        version = version.gsub(/^v/, "") if version.is_a?(String)

        return false if version.nil?

        version.to_s.match?(ANCHORED_VERSION_PATTERN)
      end

      sig { params(version: T.any(String, Gem::Version)).returns(T.nilable(T.any(String, Gem::Version))) }
      def self.semver_for(version)
        # The next two lines are to guard against improperly formatted
        # versions in a lockfile, such as an empty string or additional
        # characters. NPM/yarn fixes these when running an update, so we can
        # safely ignore these versions.
        return if version == ""
        return unless correct?(version)

        version
      end

      sig { override.params(version: T.any(String, Gem::Version)).void }
      def initialize(version)
        @version_string = T.let(version.to_s, String)
        version = version.gsub(/^v/, "") if version.is_a?(String)

        version, @build_info = version.to_s.split("+") if version.to_s.include?("+")

        super
      end

      sig { returns(Integer) }
      def major
        @major ||= T.let(segments[0] || 0, T.nilable(Integer))
      end

      sig { returns(Integer) }
      def minor
        @minor ||= T.let(segments[1] || 0, T.nilable(Integer))
      end

      sig { returns(Integer) }
      def patch
        @patch ||= T.let(segments[2] || 0, T.nilable(Integer))
      end

      sig { params(other: Dependabot::NpmAndYarn::Version).returns(T::Boolean) }
      def backwards_compatible_with?(other)
        case major
        when 0
          self == other
        else
          major == other.major && minor >= other.minor
        end
      end

      sig { override.returns(String) }
      def to_s
        @version_string
      end

      sig { override.returns(String) }
      def inspect
        "#<#{self.class} #{@version_string}>"
      end
    end
  end
end

Dependabot::Utils
  .register_version_class("npm_and_yarn", Dependabot::NpmAndYarn::Version)
