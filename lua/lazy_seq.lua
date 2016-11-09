require 'class'

clue.class("RealizedLazySeq")
clue.class("UnrealizedLazySeq")

function clue.UnrealizedLazySeq:init(fn)
    self.fn = fn
end

function clue.UnrealizedLazySeq:realize()
    self.seq = self.fn() or clue.list()
    self.fn = nil
    setmetatable(self, clue.RealizedLazySeq)
end

function clue.UnrealizedLazySeq:first()
    self:realize()
    return self.seq:first()
end

function clue.UnrealizedLazySeq:next()
    self:realize()
    return self.seq:next()
end

function clue.UnrealizedLazySeq:empty()
    self:realize()
    return self.seq:empty()
end

function clue.RealizedLazySeq:first()
    return self.seq:first()
end

function clue.RealizedLazySeq:next()
    return self.seq:next()
end

function clue.RealizedLazySeq:empty()
    return self.seq:empty()
end

clue.lazy_seq = clue.UnrealizedLazySeq.new
