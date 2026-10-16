#pragma once
#include <cstdint>
#include <cstring>
#include <functional>
#include <map>
#include <string>
#include <vector>

// BMFont v3 and EID's original fitTextToWidth algorithm. No iOS dependency.
namespace EIDBitmap {
struct Glyph {
    uint16_t x=0,y=0,w=0,h=0;
    int16_t dx=0,dy=0,advance=0;
    uint8_t page=0,channel=0;
};
struct Font {
    uint16_t lineHeight=0,base=0,width=0,height=0;
    std::vector<std::string> pages;
    std::map<uint32_t,Glyph> glyphs;
    std::map<uint64_t,int16_t> kern;
    static uint16_t U16(const uint8_t *p) { return p[0]|uint16_t(p[1])<<8; }
    static uint32_t U32(const uint8_t *p) { return U16(p)|uint32_t(U16(p+2))<<16; }
    bool Load(const uint8_t *p,size_t size) {
        *this=Font{};
        if (!p || size<4 || memcmp(p,"BMF\3",4)) return false;
        uint16_t pageCount=0;
        bool common=false,characters=false;
        for (size_t i=4;i<size;) {
            if (size-i<5) return false;
            uint8_t type=p[i]; size_t length=U32(p+i+1); i+=5;
            if (length>size-i) return false;
            const uint8_t *b=p+i; i+=length;
            if (type==2) {
                if (common || length!=15 || (b[10]&0x80)) return false;
                common=true; lineHeight=U16(b); base=U16(b+2); width=U16(b+4); height=U16(b+6); pageCount=U16(b+8);
                if (!lineHeight || lineHeight>256 || !width || !height || width>8192 || height>8192 || !pageCount || pageCount>16) return false;
            } else if (type==3) {
                if (!pages.empty()) return false;
                for (size_t j=0;j<length;) {
                    size_t end=j; while (end<length && b[end]) ++end;
                    if (end==length || end==j) return false;
                    std::string name(reinterpret_cast<const char *>(b+j),end-j);
                    if (name.find('/')!=std::string::npos || name.find('\\')!=std::string::npos || name.find("..")!=std::string::npos) return false;
                    pages.push_back(name); j=end+1;
                }
            } else if (type==4) {
                if (characters || length%20 || length/20>100000) return false;
                characters=true;
                for (size_t j=0;j<length;j+=20) {
                    uint32_t id=U32(b+j);
                    Glyph g{U16(b+j+4),U16(b+j+6),U16(b+j+8),U16(b+j+10),
                        int16_t(U16(b+j+12)),int16_t(U16(b+j+14)),int16_t(U16(b+j+16)),b[j+18],b[j+19]};
                    if (id>0x10ffff || !glyphs.emplace(id,g).second) return false;
                }
            } else if (type==5) {
                if (length%10) return false;
                for (size_t j=0;j<length;j+=10)
                    kern[(uint64_t(U32(b+j))<<32)|U32(b+j+4)]=int16_t(U16(b+j+8));
            }
        }
        if (!common || !characters || pages.size()!=pageCount || glyphs.empty()) return false;
        for (auto &entry:glyphs) {
            const Glyph &g=entry.second;
            if (g.page>=pageCount || uint32_t(g.x)+g.w>width || uint32_t(g.y)+g.h>height || g.advance<0 || g.advance>512) return false;
        }
        return true;
    }
    const Glyph *Find(uint32_t code) const {
        auto it=glyphs.find(code); if (it!=glyphs.end()) return &it->second;
        it=glyphs.find(2); return it==glyphs.end()?nullptr:&it->second;
    }
    int Kerning(uint32_t a,uint32_t b) const {
        auto it=kern.find((uint64_t(a)<<32)|b); return it==kern.end()?0:it->second;
    }
    static uint32_t Next(const std::string &text,size_t &i) {
        uint8_t first=uint8_t(text[i++]);
        if (first<128) return first;
        unsigned count=first>=0xf0?3:first>=0xe0?2:first>=0xc2?1:0;
        if (!count || first>0xf4 || text.size()-i<count) return 2;
        uint32_t code=first&((1u<<(6-count))-1);
        for (unsigned j=0;j<count;++j) {
            uint8_t b=uint8_t(text[i]); if ((b&0xc0)!=0x80) return 2;
            code=(code<<6)|(b&63); ++i;
        }
        if ((count==1 && code<128) || (count==2 && code<0x800) || (count==3 && code<0x10000) ||
            code>0x10ffff || (code>=0xd800 && code<=0xdfff)) return 2;
        return code;
    }
    int Measure(const std::string &text) const {
        int x=0; uint32_t previous=0;
        for (size_t i=0;i<text.size();) {
            uint32_t code=Next(text,i); const Glyph *g=Find(code);
            if (g) x+=Kerning(previous,code)+g->advance;
            previous=code;
        }
        return x;
    }
};
struct MeasuredWord { int width=0; bool singleIcon=false; };
using MeasureWord=std::function<MeasuredWord(const std::string &,bool)>;
inline std::vector<std::string> Wrap(std::string text,int width,bool breakUTF8,const MeasureWord &measure) {
    for (const char *tag:{"{{NoLineBreak}}","{{NoLB}}"}) {
        size_t at=text.find(tag);
        if (at!=std::string::npos) {
            for (const char *remove:{"{{NoLineBreak}}","{{NoLB}}"})
                for (size_t p=text.find(remove);p!=std::string::npos;p=text.find(remove)) text.erase(p,strlen(remove));
            return {text};
        }
    }
    std::vector<std::string> lines; std::string line;
    int current=0; bool first=true,previousIcon=false; size_t start=0;
    for (size_t cursor=0;cursor<text.size();++cursor) {
        uint8_t cur=uint8_t(text[cursor]),next=cursor+1<text.size()?uint8_t(text[cursor+1]):0;
        if (cursor+1==text.size() || cur==' ' || (breakUTF8 &&
            ((next&0xc0)==0xc0 || ((cur&0xc0)==0x80 && next!=' ' && (next&0x80)==0)))) {
            std::string word=text.substr(start,cursor+1-start);
            MeasuredWord m=measure(word,first); first=false;
            if (current+m.width<=width || current<17 || previousIcon) { line+=word; current+=m.width; }
            else { lines.push_back(line); line=word; current=m.width; }
            previousIcon=m.singleIcon; start=cursor+1;
        }
    }
    lines.push_back(line); return lines;
}
}
