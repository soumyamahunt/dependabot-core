# typed: true
# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/git_submodules/version"
require "dependabot/git_commit_checker"

module Dependabot
  module GitSubmodules
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      def latest_version
        @latest_version ||= fetch_latest_version
      end

      def latest_resolvable_version
        # Resolvability isn't an issue for submodules.
        latest_version
      end

      def latest_resolvable_version_with_no_unlock
        # No concept of "unlocking" for submodules
        latest_version
      end

      def updated_requirements
        # Submodule requirements are the URL and branch to use for the
        # submodule. We never want to update either.
        dependency.requirements
      end

      private

      def latest_version_resolvable_with_full_unlock?
        # Full unlock checks aren't relevant for submodules
        false
      end

      def updated_dependencies_after_full_unlock
        raise NotImplementedError
      end

      def fetch_latest_version
        git_commit_checker = Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials
        )

        git_commit_checker.head_commit_for_current_branch
      end
    end
  end
end

Dependabot::UpdateCheckers
  .register("submodules", Dependabot::GitSubmodules::UpdateChecker)
