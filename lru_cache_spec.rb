#! ruby -Ku
# -*- coding: utf-8 -*-
require 'lru_cache'

describe LruCache do
  describe "を初期化する場合" do
    it "は、サイズを渡したら、そのサイズのキャッシュができる." do
      targ = LruCache.new(10)
      targ.limit.should == 10
    end

    it "もし、サイズにマイナス値を渡したら、例外が発生する." do
      lambda{ LruCache.new(-1) }.should raise_error(ArgumentError)
    end

    it "もし、サイズにnilを渡したら、例外が発生する." do
      lambda{ LruCache.new(nil) }.should raise_error(ArgumentError)
    end

    it "もし、サイズに数値以外を渡したら、例外が発生する." do
      lambda{ LruCache.new("a") }.should raise_error(ArgumentError)
    end
  end

  describe "に値を出し入れする場合" do
    before :each do
      @targ = create_lru_cache(3)
    end
    
    it "は、キャッシュを入れると、入れたときと同じキーで取りだせる." do
      @targ.put("a", "A")
      @targ.get("a").should == "A"
      @targ.put("b", "B")
      @targ.get("b").should == "B"
    end

    it "は、キャッシュした個数がサイズを越えなければ、キャッシュの中で最も古いキーが取得できる." do
      @targ.fill("a", "b", "c")
      @targ.eldest_key.should == "a"
    end

    it "は、キャッシュした個数がサイズを越えると、越えた分の値が消えている." do
      @targ.fill("a", "b", "c", "d")
      @targ.get("a").should be_nil
      @targ.eldest_key.should == "b"
    end

    it "は、つねに、現在キャッシュされている値の個数が取得できる." do
      @targ.size.should == 0
      @targ.fill("a", "b")
      @targ.size.should == 2
    end

    it "もし、キャッシュの中にないキーを取り出すと、nilが返る." do
      @targ.fill("a", "b", "c")
      @targ.get("d").should be_nil
    end

    it "もし、キャッシュが空だったら、最も古いキーとしてnilが返る." do
      @targ.eldest_key.should be_nil
    end
    
    it "もし、同じキーで別のキャッシュを渡すと、同じキーのキャッシュが上書きされる." do
      @targ.fill("a", "b")
      @targ.size.should == 2
      @targ.put("a", "x")
      @targ.size.should == 2
      @targ.get("a").should == "x"
    end

    it "もし、一度最も古いキーをgetしたら、次には古いキーが最も古いキーとして取得できる." do
      @targ.fill("a", "b", "c")
      @targ.eldest_key.should == "a"
      @targ.get("a")
      @targ.eldest_key.should == "b"
    end
  end

  describe "のキャッシュサイズを変更する場合" do
    before :each do
      @targ = create_lru_cache(3)
      @targ.fill("a", "b", "c")
    end

    it "は、キャッシュサイズが変更できる." do
      @targ.limit.should == 3
      @targ.resize(100)
      @targ.limit.should == 100
    end

    it "は、キャッシュサイズを増やすと、キャッシュの内容が変わらない." do
      @targ.resize(4)
      @targ.size.should == 3
      @targ.should_have("a", "b", "c")
    end

    it "は、キャッシュサイズを減らすと、リミットを越えたキャッシュが消える." do
      @targ.resize(2)
      @targ.size.should == 2
      @targ.should_not_have("a")
      @targ.should_have("b", "c")
    end

    it "は、キャッシュが空ならば、キャッシュサイズを変更しても、例外は発生しない." do
      @targ = LruCache.new(3)
      proc{ @targ.resize(1); @targ.resize(1000); }.should_not raise_error
    end
    it "もし、新しいキャッシュサイズにマイナス値を渡すと、例外が発生する." do
      proc{ @targ.resize(-1) }.should raise_error(ArgumentError)
    end

    it "もし、新しいキャッシュサイズにnilを渡すと、例外が発生する." do
      proc{ @targ.resize(nil) }.should raise_error(ArgumentError)
    end

    it "もし、新しいキャッシュサイズに数値以外を渡すと、例外が発生する." do
      proc{ @targ.resize("a") }.should raise_error(ArgumentError)
    end

  end
  
  describe "のキャッシュの保持期間を変更する場合" do
    before :each do
      # 保存期間に10秒を設定する
      @targ = create_lru_cache(4, 10)
      @filled_time = now
      @targ.fill("a", "b", "c")
    end

    it "は、登録したキャッシュの登録時間が取得できる." do
      @targ.birthtime_of("a").should == @filled_time
    end

    it "は、getした時、保持期間を過ぎていないキャッシュが消えてはいけない." do
      set_forward(9)
      @targ.put("d", "D")
      set_forward(1)
      @targ.should_not_have("a", "b", "c")
      @targ.should_have("d")
      set_forward(9)
      @targ.should_not_have("d")
    end

    it "は、getした時、保持期間を過ぎたキャッシュがあれば消える." do
      @targ.should_have("a")
      set_forward(9)
      @targ.should_have("a")
      set_forward(1)
      @targ.should_not_have("a")
    end
  end
  
  describe "が複数スレッドでアグレッシブに実行される場合" do
    before :each do
      @targ = create_lru_cache(3)
      @targ.fill("a", "b")
    end
    
    it "は、順番にスレッドを実行すると、通常通り更新と追加ができる." do
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
    
    it "もし、スレッドを100個ぐらい実行しても、通常通り更新と追加ができる." do
      @targ.resize(100)
      t = []
      100.times do |i|
        t[i] = Thread.start do
          @targ.put(i.to_s, i.to_s)
        end
      end
      100.times do |i|
        t[i].join
      end
      100.times do |i|
        @targ.get(i.to_s).should == i.to_s
      end
    end

    it "もし、主スレッド内でロック中に子スレッドでgetすると、主スレッドがロック解除後に子スレッドの操作がeldest_keyに反映される." do
      @targ.synch_to proc {
        @targ.get("a")
      } do
        @targ.eldest_key.should == "a"
      end
      @targ.eldest_key.should == "b"
    end
    
    it "もし、主スレッド内でロック中に子スレッドでputすると、主スレッドがロック解除後に子スレッドのputが反映される." do
      @targ.synch_to proc {
        @targ.put("a", "X")
        @targ.put("c", "Y")
      } do
        @targ.get("a").should == "a"
        @targ.get("c").should be_nil
      end
      @targ.get("a").should == "X"
      @targ.get("c").should == "Y"
      @targ.eldest_key.should == "b"
    end
    
    it "もし、主スレッド内でロック中に子スレッドでputしつつ主スレッドでもputすると、先に主スレッドのputが反映され、ロック解除後に子スレッドのputが反映される." do
      @targ.synch_to proc {
        @targ.put("a", "X")
        @targ.put("c", "Y")
      } do
        @targ.put("a", "A")
        @targ.put("c", "C")
        @targ.get("a").should == "A"
        @targ.get("c").should == "C"
      end
      @targ.get("a").should == "X"
      @targ.get("c").should == "Y"
    end
    
    it "もし、スレッド内でロック中に子スレッドでresizeすると、主スレッドがロック解除後に子スレッドのresizeが反映される." do
      @targ.synch_to proc {
        @targ.resize(2)
      } do
        @targ.limit.should == 3
      end
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

  def synch_to(co_thread)
    t = nil
    synchronize do
      t = Thread.start do
        co_thread.call
      end
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

def create_lru_cache(size, lifespan = 10)
  targ = LruCache.new(size, lifespan)
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
