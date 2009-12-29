#! ruby -Ku
# -*- coding: utf-8 -*-
require 'lru_cache'

describe LruCache do
  describe "初期化に関するテスト" do
    it "サイズを渡したらそのサイズのキャッシュができること" do
      targ = LruCache.new(10)
      targ.limit.should == 10
    end

    it "サイズにマイナス値を渡した場合、例外が発生すること" do
      lambda{ LruCache.new(-1) }.should raise_error(ArgumentError)
    end

    it "サイズにnilを渡した場合、例外が発生すること" do
      lambda{ LruCache.new(nil) }.should raise_error(ArgumentError)
    end

    it "サイズに数値以外を渡した場合、例外が発生すること" do
      lambda{ LruCache.new("a") }.should raise_error(ArgumentError)
    end
  end

  describe "値の出し入れに関するテスト" do
    before :each do
      @targ = create_lru_cache(3)
    end
    
    it "入れたものが同じキーで取りだせること" do
      @targ.put("a", "A")
      @targ.get("a").should == "A"
      @targ.put("b", "B")
      @targ.get("b").should == "B"
    end

    it "キャッシュの中にないキーを取り出すとnilが返ること" do
      @targ.fill("a", "b", "c")
      @targ.get("d").should be_nil
    end

    it "キャッシュがサイズを越えない場合、キャッシュの中で最も古いキーが取得できること" do
      @targ.fill("a", "b", "c")
      @targ.eldest_key.should == "a"
    end

    it "キャッシュが空の場合、最も古いキーとしてnilが返ること" do
      @targ.eldest_key.should be_nil
    end

    it "キャッシュがサイズを越えた場合、越えた分の値が消えていること" do
      @targ.fill("a", "b", "c", "d")
      @targ.get("a").should be_nil
      @targ.eldest_key.should == "b"
    end

    it "現在キャッシュされている値の個数が取得できること" do
      @targ.size.should == 0
      @targ.fill("a", "b")
      @targ.size.should == 2
    end
    
    it "同じキーを渡した場合、上書きされること" do
      @targ.fill("a", "b")
      @targ.size.should == 2
      @targ.put("a", "x")
      @targ.size.should == 2
      @targ.get("a").should == "x"
    end

    it "最も古いキーをgetすると次に古いキーが最も古いキーとして取得できること" do
      @targ.fill("a", "b", "c")
      @targ.eldest_key.should == "a"
      @targ.get("a")
      @targ.eldest_key.should == "b"
    end
  end

  describe "キャッシュサイズ変更に関するテスト" do
    before :each do
      @targ = create_lru_cache(3)
      @targ.fill("a", "b", "c")
    end

    it "新しいキャッシュサイズにマイナス値を渡した場合、例外が発生すること" do
      lambda{ @targ.resize(-1) }.should raise_error(ArgumentError)
    end

    it "新しいキャッシュサイズにnilを渡した場合、例外が発生すること" do
      lambda{ @targ.resize(nil) }.should raise_error(ArgumentError)
    end

    it "新しいキャッシュサイズに数値以外を渡した場合、例外が発生すること" do
      lambda{ @targ.resize("a") }.should raise_error(ArgumentError)
    end

    it "キャッシュサイズが変更できること" do
      @targ.limit.should == 3
      @targ.resize(100)
      @targ.limit.should == 100
    end

    it "キャッシュサイズを増やした場合、キャッシュの内容が変わらないこと" do
      @targ.resize(4)
      @targ.size.should == 3
      @targ.should_have("a", "b", "c")
    end

    it "キャッシュサイズを減らした場合、リミットを越えたキャッシュが消えること" do
      @targ.resize(2)
      @targ.size.should == 2
      @targ.should_not_have("a")
      @targ.should_have("b", "c")
    end

    it "キャッシュが空の場合に、キャッシュサイズを変更してもエラーが起こらないこと" do
      @targ = LruCache.new(3)
      lambda{ @targ.resize(1); @targ.resize(1000); }.should_not raise_error
    end
  end
  
  describe "キャッシュの保持期間に関するテスト" do
    before :each do
      # 保存期間に10秒を設定する
      @targ = create_lru_cache(4)
      @filled_time = now
      @targ.fill("a", "b", "c")
    end

    it "キャッシュが登録された時間が取得できること" do
      @targ.birthtime_of("a").should == @filled_time
    end

    it "保持期間を過ぎたキャッシュが消えること" do
      @targ.should_have("a")
      set_forward(9)
      @targ.should_have("a")
      set_forward(1)
      @targ.should_not_have("a")
    end

    it "保持期間を過ぎていないキャッシュが消えないこと" do
      set_forward(9)
      @targ.put("d", "D")
      set_forward(1)
      @targ.should_not_have("a", "b", "c")
      @targ.should_have("d")
      set_forward(9)
      @targ.should_not_have("d")
    end
  end
  
  describe "スレッドセーフに関するテスト" do
    before :each do
      @targ = create_lru_cache(3)
      @targ.fill("a", "b")
    end
    
    it "順番にスレッドを実行すると、通常通り更新と追加ができること" do
      t1 = Thread.start do
        @targ.put("a", "X")
        @targ.get("a").should == "X"
      end
      t2 = Thread.start do
        @targ.put("c", "Y")
        @targ.get("c").should == "Y"
      end
      t1.join
      t2.join
      @targ.get("a").should == "X"
      @targ.get("c").should == "Y"
    end
    
    it "主スレッド内でロック中に別スレッドでgetすると、主スレッドがロック解除後にeldest_keyに反映されること" do
      t = nil
      @targ.synchronize do
        t = Thread.start do
          @targ.get("a")
        end
        @targ.eldest_key.should == "a"
      end
      t.join
      @targ.eldest_key.should == "b"
    end
    
    it "主スレッド内でロック中に別スレッドでputすると、主スレッドがロック解除後にputされること" do
      t = nil
      @targ.synchronize do
        t = Thread.start do
          @targ.put("a", "X")
          @targ.put("c", "Y")
        end
        @targ.get("a").should == "a"
        @targ.get("c").should be_nil
      end
      t.join
      @targ.get("a").should == "X"
      @targ.get("c").should == "Y"
      @targ.eldest_key.should == "b"
    end
    
    it "主スレッド内でロック中に別スレッドでputしつつ主スレッドでもputすると、主スレッドのputが反映され、ロック解除後に別スレッドのputが反映されること" do
      t = nil
      @targ.synchronize do
        t = Thread.start do
          @targ.put("a", "X")
          @targ.put("c", "Y")
        end
        @targ.put("a", "A")
        @targ.put("c", "C")
        @targ.get("a").should == "A"
        @targ.get("c").should == "C"
      end
      t.join
      @targ.get("a").should == "X"
      @targ.get("c").should == "Y"
      @targ.eldest_key.should == "b"
    end
    
    it "スレッド内でロック中に別スレッドでresizeすると、主スレッドがロック解除後にresizeが反映されること" do
      t = nil
      @targ.synchronize do
        t = Thread.start do
          @targ.resize(2)
        end
        @targ.limit.should == 3
      end
      t.join
      @targ.limit.should == 2
    end
  end
end

module TestMethods
  def fill(*keys)
    keys.each do |v|
      put(v, v)
    end
  end

  def lock
    t = nil
    synchronize do
      yield
    end
    t.join
  end

  def should_have(*keys)
    keys.each do |v|
      get(v).should_not == nil
    end
  end

  def should_not_have(*keys)
    keys.each do |v|
      get(v).should == nil
    end
  end
end

def create_lru_cache(num)
  targ = LruCache.new(num, 10)
  targ.extend TestMethods
  return targ
end

def now
  set_forward(0)
end

def set_forward(second)
  time = Time.now + second
  Time.stub!(:now).and_return(time)
  return time
end
