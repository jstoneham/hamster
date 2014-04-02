require "spec_helper"

require "hamster/hash"

describe ::Hash do

  [:eql?, :==].each do |method|

    describe "##{method}" do

      describe "returns true when comparing with" do

        before do
          @hash = Hamster.hash("A" => "aye", "B" => "bee", "C" => "see")
        end

        it "a Hamster hash" do
          {"A" => "aye", "B" => "bee", "C" => "see"}.send(method, @hash).should == true
        end

      end

    end

  end

end

describe Hamster::Hash do

  [:eql?, :==].each do |method|

    describe "##{method}" do

      before do
        @hash = Hamster.hash("A" => "aye", "B" => "bee", "C" => "see")
      end

      describe "returns true when comparing with" do

        it "a standard hash" do
          @hash.send(method, "A" => "aye", "B" => "bee", "C" => "see").should == true
        end

      end

      describe "returns false when comparing with" do

        it "an arbitrary object" do
          @hash.send(method, Object.new).should == false
        end

      end

      [
        [{}, {}, true],
        [{ "A" => "aye" }, {}, false],
        [{}, { "A" => "aye" }, false],
        [{ "A" => "aye" }, { "A" => "aye" }, true],
        [{ "A" => "aye" }, { "B" => "bee" }, false],
        [{ "A" => "aye", "B" => "bee" }, { "A" => "aye" }, false],
        [{ "A" => "aye" }, { "A" => "aye", "B" => "bee" }, false],
        [{ "A" => "aye", "B" => "bee", "C" => "see" }, { "A" => "aye", "B" => "bee", "C" => "see" }, true],
        [{ "C" => "see", "A" => "aye", "B" => "bee" }, { "A" => "aye", "B" => "bee", "C" => "see" }, true],
      ].each do |a, b, expected|

        describe "returns #{expected.inspect}" do

          before do
            @a = Hamster.hash(a)
            @b = Hamster.hash(b)
          end

          it "for #{a.inspect} and #{b.inspect}" do
            @a.send(method, @b).should == expected
          end

          it "for #{b.inspect} and #{a.inspect}" do
            @b.send(method, @a).should == expected
          end

        end

      end

    end

  end

end
