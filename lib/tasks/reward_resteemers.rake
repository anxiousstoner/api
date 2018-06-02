require 'radiator'
require 'utils'
require 's_logger'

desc 'Reward Resteemers'
task :reward_resteemers => :environment do |t, args|
  TEST_MODE = true # Should be false on production
  HUNT_DISTRIBUTION_RESTEEM = 20000.0

  logger = SLogger.new
  api = Radiator::Api.new
  today = Time.zone.today.to_time
  yesterday = (today - 1.day).to_time

  logger.log "\n==\n========== #{HUNT_DISTRIBUTION_RESTEEM} HUNT DISTRIBUTION ON RESTEEMERS ==========", true

  posts = Post.where('created_at >= ? AND created_at < ?', yesterday, today).
    where(is_active: true, is_verified: true).
    order('payout_value DESC')
  logger.log "Total #{posts.count} verified posts founds\n=="

  has_resteemed = {}
  posts.each_with_index do |post, i|
    logger.log "@#{post.author}/#{post.permlink}"

    resteemed_by = with_retry(3) do
      api.get_reblogged_by(post.author, post.permlink)['result']
    end

    logger.log "--> RESTEEM COUNT: #{resteemed_by.size}"
    resteemed_by.each do |username|
      has_resteemed[username] = true unless has_resteemed[username]
    end
  end

  # HUNT resteem distribution
  resteemed_users = has_resteemed.keys.sort
  hunt_per_resteem = HUNT_DISTRIBUTION_RESTEEM / resteemed_users.size
  resteemed_users.each do |username|
    HuntTransaction.reward_resteems!(username, hunt_per_resteem, yesterday) unless TEST_MODE
  end

  if TEST_MODE
    logger.log "TEST - Distributed #{hunt_per_resteem} HUNT to:\n#{resteemed_users}"
  else
    logger.log "Distributed #{hunt_per_resteem} HUNT to:\n#{resteemed_users}"
  end
end