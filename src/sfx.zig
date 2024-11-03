/// A simple EventSystem
/// Has an ArrayList for every event
/// Simply consumes then once "handle is called"
/// - use append(item) to add to queue
const std = @import("std");
const rl = @import("raylib");

pub const AliasData = struct {
    is_on: bool = false,
    alias: rl.Sound,
};

pub const LoopEffect = struct {
    allocator: std.mem.Allocator,
    sound_ptr: *rl.Sound,
    aliases: std.ArrayListUnmanaged(AliasData),

    pub fn init(allocator: std.mem.Allocator, sound_ptr: *rl.Sound, capacity: usize) !LoopEffect {
        var aliases: std.ArrayListUnmanaged(AliasData) = .{};
        for (0..capacity) |_| {
            try aliases.append(
                allocator,
                .{
                    .is_on = false,
                    .alias = sound_ptr.*,
                },
            );
        }

        return .{
            .allocator = allocator,
            .sound_ptr = sound_ptr,
            .aliases = aliases,
        };
    }

    pub fn deinit(self: *LoopEffect) void {
        self.aliases.deinit(self.allocator);
    }

    pub fn update(self: *LoopEffect) void {
        for (0.., self.aliases.items) |idx, alias_data| {
            if (self.aliases.items[idx].is_on) {
                if (!rl.isSoundPlaying(alias_data.alias)) {
                    rl.playSound(alias_data.alias);
                }
            }
        }
    }

    pub fn play(self: *LoopEffect) ?usize {
        for (0.., self.aliases.items) |idx, alias_data| {
            if (!rl.isSoundPlaying(alias_data.alias)) {
                self.aliases.items[idx].is_on = true;
                rl.playSound(alias_data.alias);
                return idx;
            }
        }
        std.log.debug("Couldn't play sound. No alias available! All are playing.", .{});
        return null;
    }

    pub fn stop(self: *LoopEffect, i: usize) void {
        rl.stopSound(self.aliases.items[i].alias);
        self.aliases.items[i].is_on = false;
    }
};

pub const SoundEffect = struct {
    allocator: std.mem.Allocator,
    sound_ptr: *rl.Sound,
    aliases: std.ArrayListUnmanaged(rl.Sound),

    pub fn init(allocator: std.mem.Allocator, sound_ptr: *rl.Sound, capacity: usize) !SoundEffect {
        var aliases: std.ArrayListUnmanaged(rl.Sound) = .{};
        for (0..capacity) |_| {
            try aliases.append(allocator, rl.loadSoundAlias(sound_ptr.*));
        }

        return .{
            .allocator = allocator,
            .sound_ptr = sound_ptr,
            .aliases = aliases,
        };
    }

    pub fn deinit(self: *SoundEffect) void {
        self.aliases.deinit(self.allocator);
    }

    pub fn play(self: *SoundEffect) ?usize {
        for (0.., self.aliases.items) |idx, sound| {
            if (!rl.isSoundPlaying(sound)) {
                rl.playSound(sound);
                return idx;
            }
        }
        std.log.debug("Couldn't play sound. No alias available! All are playing.", .{});
        return null;
    }

    pub fn stop(self: *SoundEffect, i: usize) void {
        rl.stopSound(self.alias[i]);
    }
};

pub const ThresholdSoundEffect = struct {
    allocator: std.mem.Allocator,
    base_sound_ptr: *rl.Sound,
    threshold_sound_ptr: *rl.Sound,
    aliases: []rl.Sound,
    pub fn init(allocator: std.mem.Allocator, sound_ptr: *rl.Sound, capacity: usize) !SoundEffect {
        const aliases = try allocator.alloc(rl.Sound, capacity);
        return .{
            .allocator = allocator,
            .sound_ptr = sound_ptr,
            .aliases = aliases,
        };
    }

    pub fn deinit(self: ThresholdSoundEffect) void {
        self.allocator.free(self.aliases);
    }

    pub fn play(self: *SoundEffect) usize {
        for (self.aliases) |sound| {
            if (!rl.isSoundPlaying(sound)) {
                rl.playSound(sound);
                break;
            }
        } else {
            // TODO(MO):
            // we might need to keep track on playtime of other sounds
            // so that we only play as long as the critical amount
            // "should" be playing
            for (self.aliases) |sound| {
                rl.stopSound(sound);
            }

            if (!rl.isSoundPlaying(self.threshold_sound_ptr.*)) {
                rl.playSound(self.threshold_sound_ptr.*);
            }
        }
    }

    pub fn stop(self: *SoundEffect, i: usize) void {
        rl.stopSound(self.alias[i]);
    }
};
