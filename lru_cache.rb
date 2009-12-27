class LruCache
  attr_reader :limit

  def initialize(size, lifespan = 10)
    raise ArgumentError.new unless valid_size?(size)
    @limit = size
    @cache = []
    @lifespan = lifespan
  end

  def put(key, value)
    remove_cache(key) if pick_out(key) != nil
    @cache << CacheValue.new(key, value)
    if @cache.size > @limit then
      @cache.shift
    end
  end

  def get(key)
    ret = pick_out(key)
    return ret == nil ? nil : ret.value
  end

  def size
    return @cache.size
  end

  def resize(size)
    raise ArgumentError.new unless valid_size?(size)
    (@limit - size).times do
      @cache.shift
    end
    @limit = size
  end

  def valid_size?(size)
    return size != nil && size > 0
  end
  
  def eldest_key
    return nil if @cache.size <= 0
    return @cache[0].key
  end

  def birthtime_of(key)
    ret = pick_out(key)
    return ret == nil ? nil : ret.birthtime
  end

  private

  def pick_out(key)
    remove_dead_caches
    @cache.each do |v|
      if v.key == key then
        rotate(v)
        return v
      end
    end
    return nil
  end
  
  def rotate(value)
    remove_cache(value.key)
    @cache << value
  end

  def remove_cache(key)
    @cache.each do |v|
      @cache.delete(v) if v.key == key
    end
  end

  def remove_dead_caches
    @cache.each do |v|
      lifetime = Time.now - v.birthtime
      remove_cache(v.key) if lifetime >= @lifespan
    end
  end
end

class CacheValue
  attr_reader :key, :value, :birthtime
  
  def initialize(key, value)
    @key = key
    @value = value
    @birthtime = Time.now
  end
end
