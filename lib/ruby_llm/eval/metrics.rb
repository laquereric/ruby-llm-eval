# frozen_string_literal: true

module RubyLLM
  module Eval
    module Metrics
      class << self
        # pass@k: probability of at least one success in k trials
        # Formula: 1 - C(n-c, k) / C(n, k) where c = pass_count, n = total
        def pass_at_k(pass_count, fail_count, k)
          n = pass_count + fail_count
          return 0.0 if n.zero? || k.zero?
          return 1.0 if pass_count >= n

          k = [k, n].min
          # 1 - C(n-c, k) / C(n, k)
          numerator = combination(n - pass_count, k)
          denominator = combination(n, k)
          return 0.0 if denominator.zero?

          (1.0 - numerator.to_f / denominator).clamp(0.0, 1.0)
        end

        # pass^k: probability ALL k trials succeed
        # Formula: p^k where p = pass_rate
        def pass_pow_k(pass_rate, k)
          return 0.0 if k.zero?

          (pass_rate**k).clamp(0.0, 1.0)
        end

        private

        def combination(n, k)
          return 0 if k > n || k < 0
          return 1 if k.zero? || k == n

          k = n - k if k > n - k
          (1..k).reduce(1) { |r, i| r * (n - i + 1) / i }
        end
      end
    end
  end
end
