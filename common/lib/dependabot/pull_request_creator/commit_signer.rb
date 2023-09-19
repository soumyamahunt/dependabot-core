# typed: false
# frozen_string_literal: true

require "time"
require "tmpdir"
require "dependabot/pull_request_creator"

module Dependabot
  class PullRequestCreator
    class CommitSigner
      attr_reader :author_details, :commit_message, :tree_sha, :parent_sha,
                  :signature_key

      def initialize(author_details:, commit_message:, tree_sha:, parent_sha:,
                     signature_key:)
        @author_details = author_details
        @commit_message = commit_message
        @tree_sha = tree_sha
        @parent_sha = parent_sha
        @signature_key = signature_key
      end

      def signature
        begin
          require "gpgme"
        rescue LoadError
          raise LoadError, "Please add `gpgme` to your Gemfile or gemspec " \
                           "enable commit signatures"
        end

        email = author_details[:email]

        dir = Dir.mktmpdir

        GPGME::Engine.home_dir = dir
        GPGME::Key.import(signature_key)

        crypto = GPGME::Crypto.new(armor: true)
        opts = { mode: GPGME::SIG_MODE_DETACH, signer: email }
        crypto.sign(commit_object, opts).to_s
      rescue Errno::ENOTEMPTY
        FileUtils.remove_entry(dir, true)
        # This appears to be a Ruby bug which occurs very rarely
        raise if @retrying

        @retrying = true
        retry
      ensure
        FileUtils.remove_entry(dir, true)
      end

      private

      def commit_object
        time_str = Time.parse(author_details[:date]).strftime("%s %z")
        name = author_details[:name]
        email = author_details[:email]

        [
          "tree #{tree_sha}",
          "parent #{parent_sha}",
          "author #{name} <#{email}> #{time_str}",
          "committer #{name} <#{email}> #{time_str}",
          "",
          commit_message
        ].join("\n")
      end
    end
  end
end
