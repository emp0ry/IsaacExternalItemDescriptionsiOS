#pragma once
#include <cstdint>
#include <cstddef>
#include <cmath>
#include <array>

// Shared, read-only presentation boundary for the verified Isaac iOS 1.4
// UUID. Each independent mod includes its own copy; no other mod is required.
namespace IsaacPresentation {
struct State {
    uintptr_t manager=0,game=0,room=0,roomDescriptor=0;
    uint32_t mode=0,seed=0;
    uint8_t pending=1,hud=0,fullscreenPlaying=0;
    int pause=-1,roomTransition=-1,fadeState=-1,bossIntro=-1,deathScreen=-1,cutscene=-1;
    int rewardScreen=-1,entryTimer=0,overlayTimer=0;
    float fade=1,whiteFade=1;
    bool RunVisible(bool allowPause) const {
        return mode==2 && manager && game && room && roomDescriptor && seed && !pending && hud==1 &&
            (pause==0 || (allowPause && pause==1)) && roomTransition==0 && fadeState==0 &&
            bossIntro==0 && deathScreen==0 && cutscene==0 && rewardScreen>=0 && rewardScreen<2 &&
            entryTimer<=0 && overlayTimer<=0 && !fullscreenPlaying &&
            std::isfinite(fade) && fade==0 && std::isfinite(whiteFade) && whiteFade<=0;
    }
    bool OverlayVisible() const { return (mode==1 && manager) || RunVisible(true); }
};

// Require a short continuous clear interval after a scene/room change. An
// intermediate idle update during loading must not flash the previous overlay.
class Visibility {
    uintptr_t game_=0,room_=0,manager_=0;
    uint32_t seed_=0,mode_=0;
    double clearSince_=-1,last_=0;
public:
    bool Observe(const State& s,bool captured,bool allowPause,bool allowMenu,double now) {
        bool clear=captured && (allowMenu ? s.OverlayVisible() : s.RunVisible(allowPause));
        if (!clear || !std::isfinite(now) || now<last_) { clearSince_=-1; last_=now; return false; }
        if (clearSince_<0 || game_!=s.game || room_!=s.roomDescriptor ||
            seed_!=s.seed || manager_!=s.manager || mode_!=s.mode) {
            clearSince_=now; game_=s.game; room_=s.roomDescriptor; seed_=s.seed;
            manager_=s.manager; mode_=s.mode;
        }
        last_=now;
        return now-clearSince_>=.1;
    }
};
template<class Reader> bool Validate(uintptr_t base,const Reader& read) {
    struct Signature { uintptr_t rva; std::array<uint32_t,4> words; };
    const Signature signatures[]={
        {0x6a8b98,{0xb9400008,0x121f7908,0x7100091f,0x1a9f17e0}},
        {0x89b2f0,{0xb9400008,0x121f7909,0x1e3e1000,0x7100093f}},
        {0x76b7b0,{0xa9027bfd,0x910083fd,0xb9400008,0x34000388}},
        {0x7ea2fc,{0xb9400008,0x34003668,0xaa0003f6,0xb81703bf}},
        {0x575354,{0xb9400008,0x7100091f,0x54000b03,0xaa0003f3}},
        {0x89e9dc,{0xaa0003e8,0xf9401c00,0xb40001e0,0x39415108}},
        {0x88ebdc,{0xb94012e8,0x7100051f,0x54000f4b,0xf9400388}},
        {0x88efa4,{0xb94022e8,0x7100051f,0x540017eb,0xf00011b3}},
        {0x88f524,{0xbd407ae0,0x1e202008,0x540003cd,0xd00011a0}},
        {0x88f5a4,{0xbd407ee0,0x1e202008,0x540002cd,0xb9009bff}},
    };
    for (const auto& signature:signatures) {
        std::array<uint32_t,4> actual{};
        if (!read(base+signature.rva,actual.data(),sizeof(actual)) || actual!=signature.words) return false;
    }
    return true;
}
template<class Reader> bool Capture(uintptr_t base,const Reader& read,State& s) {
    s={};
    if (!read(base+0xac2428,&s.manager,8) || !s.manager ||
        !read(s.manager+0x204c0,&s.mode,4)) return false;
    if (s.mode!=2) return true;
    uintptr_t animation=0; uint8_t playing=0;
    bool captured=read(base+0xac3b90,&s.game,8) && s.game &&
        read(s.manager+0x1f6b40,&s.pending,1) &&
        read(s.game+0x21550,&s.room,8) && s.room && read(s.room+8,&s.roomDescriptor,8) &&
        read(s.game+0x25d44,&s.seed,4) &&
        read(s.game+0x10dfd8,&s.pause,4) && read(s.game+0x10d45a,&s.hud,1) &&
        read(s.game+0x25810,&s.roomTransition,4) && // RoomTransition render / IsActive
        read(s.game+0x25c00,&s.fadeState,4) &&     // full-screen fade render
        read(s.game+0x27390,&s.bossIntro,4) &&     // native full-screen cutscene
        read(s.game+0x27630,&s.deathScreen,4) &&   // game-over screen render
        read(s.game+0x47aa0+0x264,&s.cutscene,4) && // native cinematic overlay render
        read(s.game+0x25db0,&s.rewardScreen,4) && // boss/large animation render, state >= 2
        read(s.game+0x1cf3d8,&s.entryTimer,4) && // post-HUD full-screen counters
        read(s.game+0x1cf3e8,&s.overlayTimer,4) &&
        read(s.game+0x1cf708+0x38,&animation,8) &&
        read(s.game+0x1cf708+0x54,&playing,1) && // same predicate as native IsPlaying("")
        read(s.game+0x1cf440,&s.whiteFade,4) &&
        read(s.game+0x1cf444,&s.fade,4);
    s.fullscreenPlaying=animation && playing;
    return captured;
}
}
