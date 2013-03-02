$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'retjilp/retweeter'
require 'retjilp/twitter'

module Retjilp 
	describe Retweeter do
		let(:twitter) { double(Twitter) }

		before (:each) do
			twitter.stub(:login)
		end

		context 'match keyword' do
			let(:retweeter) { Retweeter.new(twitter, :match => ['MatchingKeyword']) }

			context 'empty user timeline' do
				before(:each) do
					twitter.stub(:user_timeline) {[]}
				end

				it 'retweets new matching items' do
					twitter.stub(:home_timeline) {[{'text' => 'MatchingKeyword', 'id' => 'id1'}]}
					twitter.should_receive(:retweet).with('id1')
					retweeter.run
				end

				it 'does not retweet non-matching items' do
					twitter.stub(:home_timeline) {[{'text' => 'OtherKeyword', 'id' => 'id1'}]}
					twitter.should_not_receive(:retweet)
					retweeter.run
				end

				it 'retweets retweets with their id' do
					twitter.stub(:home_timeline) {[{'text' => 'MatchingKeyword', 'id' => 'id1', 'retweeted_status' => {'id' => 'id2'}}]}
					twitter.should_receive(:retweet).with('id2')
					retweeter.run
				end
			end

			context 'user timeline with already retweeted items' do
				before(:each) do
					twitter.stub(:user_timeline) {[{}, {'retweeted_status' => {'id' => 'id1'}}]}
				end

				it 'does not retweet already tweeted items' do
					twitter.stub(:home_timeline) {[{'text' => 'MatchingKeyword', 'id' => 'id1'}]}
					twitter.should_not_receive(:retweet)
					Retweeter.new(twitter, :match => ['MatchingKeyword']).run
				end
			end
		end

		context 'match is empty' do
			let(:retweeter) { Retweeter.new(twitter, :match => []) }

			it 'retweets all items' do
				twitter.stub(:user_timeline) {[]}
				twitter.stub(:home_timeline) {[{'text' => 'OtherKeyword', 'id' => 'id1'}]}

				twitter.should_receive(:retweet).with('id1')

				retweeter.run
			end
		end

		context 'retweet from list' do
			let(:retweeter) { Retweeter.new(twitter, :retweet_from_list => 'MyList', :match => ['MatchingKeyword']) }

			it 'retweets from the right list' do
				twitter.stub(:user_timeline) {[]}
				twitter.should_receive(:list_statuses).with('MyList', anything()).and_return([
					{'text' => 'MatchingKeyword', 'id' => 'id1'},
					{'text' => 'OtherKeyword', 'id' => 'id2'}
				])
				twitter.should_receive(:retweet).with('id1')
				retweeter.run
			end
		end

	end
end
