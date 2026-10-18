/// 403a40 blocks by the AI's own Object id. A block returns true after it
/// sets a command byte (+0xd4..0xdc = 3) or presses buttons and ends the AI
/// call; false continues the chain, which no later block matches.
extension OriginalCharacterAIPass {
    mutating func command(_ s: Int,_ offset: Int) throws -> Bool { try byte(s,offset,3); return true }
    /// 404a75/4053de/404185: 0xd8 toward a target on the right, else 0xd9.
    mutating func aimed(_ s: Int,_ t: Int) throws -> Bool { try command(s,i(t,0x10) > i(s,0x10) ? 0xd8 : 0xd9) }
    /// Low-health test used for healing: below max-margin and 140, or below
    /// 3/5 of max while at least 140.
    func wounded(_ a: Int,margin: Int32) throws -> Bool {
        let hp = try i(a,0x2fc),max = try i(a,0x300)
        return (hp < max &- margin && hp < 140) || (hp < (max &* 3)/5 && hp >= 140)
    }
    func dx(_ s: Int,_ t: Int) throws -> Int32 { abs(try i(t,0x10) &- i(s,0x10)) }
    func dz(_ s: Int,_ t: Int) throws -> Int32 { abs(try i(t,0x18) &- i(s,0x18)) }
    /// Facing the target: facing 0 needs it to the right, facing 1 to the left.
    func facingToward(_ s: Int,_ x: Int32) throws -> Bool {
        let f = try facing(s),sx = try i(s,0x10)
        return (f == 0 && x > sx) || (f == 1 && x < sx)
    }

    /// 403a7e..403e83 (Naruto).
    mutating func naruto2(_ s: Int,_ t: Int,slot: Int,_ l: Locals) throws -> Bool {
        if try draw(0x3d,10) == 0, try i(s,0x308) > 350, try wounded(s,margin: 70) { return try command(s,0xdb) }
        if l.nearest38 < 10000, try draw(0x3e,30) == 0, try i(s,0x308) > 250 { return try command(s,0xd6) }
        let strong = try [2,9,10,11,33,34].contains(id(t))
        if try draw(strong ? 0x3f : 0x40,15) == 0 {
            let d = try dx(s,t)
            if try d > 100 && d < (strong ? 500 : 250) && dz(s,t) < 30 && i(s,0x308) > 100
                && i(t,0x308) > (strong ? 220 : 170) && l.ball30 == 0 { return try aimed(s,t) }
        }
        return try healAlly(s,slot: slot,l)
    }

    /// 403ca1..403e7f with tail 403f67..403fd4 (Naruto) and 4055fa..40575b
    /// with tail 40587c..405910 (Kidomaru): walk to a wounded teammate among
    /// slots 0..19 and request 0xda when facing it or within 5.
    mutating func healAlly(_ s: Int,slot: Int,_ l: Locals) throws -> Bool {
        if try i(s,0x98) != 0 && i(s,0x70) >= 9 { return false }
        if try wounded(s,margin: 70) || l.aligned34 != 0 { return false }
        for k in 0..<20 where k != slot {
            guard try active(k) != 0 else { continue }
            let a = try index(k),team = try i(a,0x364)
            guard team != 0, try team == i(s,0x364) else { continue }
            let ax = try dx(s,a)
            guard ax < 250 else { continue }
            let az = try dz(s,a)
            guard az < 60, try i(s,0x308) > 350, try wounded(a,margin: 90), try i(a,0x2fc) > 0, az &+ ax < l.nearest38/3 else { continue }
            if try i(a,0x10) > i(s,0x10) { try press(s,.right); try byte(s,Key.left.rawValue,0) }
            else { try byte(s,Key.right.rawValue,0); try press(s,.left) }
            let x = try i(index(k),0x10)
            if try facingToward(s,x) || abs(x &- i(s,0x10)) < 5 { try byte(s,0xda,3) }
            return true
        }
        return false
    }

    /// 403e83..4041e4 (Sakura).
    mutating func sakura1(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        let frame = try i(s,0x70)
        if frame >= 260 && frame <= 289, try dx(s,t) < 100, try dz(s,t) < 7 {
            if try i(t,0x14) == 0 && i(s,0x14) == 0, try draw(0x41,3) == 0 { try press(s,.attack); try release(s,.attack); return true }
            if try i(t,0x14) < 0 && i(s,0x14) < 0 {
                if try draw(0x42,7) == 0 { try press(s,.attack); try release(s,.attack); return true }
            }
            let dive = try i(t,0x14) < 0 && draw(0x43,5) == 0
            if !dive, try draw(0x44,30) != 0 { return true }
            if try facingToward(s,i(t,0x10)) { try press(s,.jump) }
            try release(s,.jump); return true
        }
        if try draw(0x45,7) == 0, try dx(s,t) < 150, try dz(s,t) < 8, try i(s,0x308) > 150 {
            if try draw(0x46,10) == 0 && l.tState != 3 { return try aimed(s,t) }
            if try draw(0x47,3) > 0 && [16,8,11].contains(l.tState) { return try aimed(s,t) }
        }
        guard try draw(0x48,7) == 0, try dx(s,t) < 100, try dz(s,t) < 7, try i(s,0x308) > 75 else { return false }
        if try i(s,0x308) > 150 {
            if try draw(0x49,10) == 0 && l.tState != 3 { return try aimed(s,t) }
            if try draw(0x4a,3) > 0 && l.tState == 16 { return try aimed(s,t) }
        }
        return try command(s,0xd7)
    }

    /// 4041e4..404361 (Sai).
    mutating func sai4(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 360, try dx(s,t) < 100, try dz(s,t) < 70, try draw(0x4b,i(s,0x2fc)/5 &+ 10) == 0 { return try command(s,0xda) }
        if try draw(0x4c,45) == 0 {
            let d = try dx(s,t)
            if try d > 100 && d < 550 && dz(s,t) < 20 && i(s,0x308) > 170 { return try aimed(s,t) }
        }
        guard try draw(0x4d,30) == 0, try i(s,0x308) > 200 else { return false }
        let d = try dx(s,t)
        if try d > 100 && d < 160 && dz(s,t) < 55 && facingToward(s,i(t,0x10)) { return try command(s,0xdc) }
        return false
    }

    /// 404361..4044ed (Shino).
    mutating func shino5(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 450, try dx(s,t) > 100, try dz(s,t) > 50, try draw(0x4e,3) == 0 {
            return try command(s,try draw(0x4f,2) == 0 ? 0xda : 0xdb)
        }
        if try i(s,0x308) > 70, try dx(s,t) > 100, try dx(s,t) < 160, try dz(s,t) < 8, try draw(0x50,10) == 0 { return try aimed(s,t) }
        guard try draw(0x51,30) == 0, try i(s,0x308) > 200 else { return false }
        let d = try dx(s,t),tx = try i(t,0x10),sx = try i(s,0x10),f = try facing(s)
        if try d > 100 && d < 160 && dz(s,t) < 55 {
            if f == 0 && tx > sx { return try command(s,0xd4) }
            if f == 1 && tx < sx { return try command(s,0xd5) }
        }
        return false
    }

    /// 4044ed..4045fc (Hsasori). The jump press still lets the chain return 0.
    mutating func hsasori6(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 100, try dx(s,t) > 80, try dx(s,t) < 130, try dz(s,t) < 30, try draw(0x52,10) == 0 { return try aimed(s,t) }
        if try i(s,0x308) > 100, try dx(s,t) < 45, try dz(s,t) < 5, try draw(0x53,3) == 0 { return try command(s,0xda) }
        if try state(s) == 9, try draw(0x54,8) == 0 { try press(s,.jump); try release(s,.jump) }
        return false
    }

    /// 4045fc..40498d with its tails 404aa5..404ae3 (Rock Lee).
    mutating func lee7(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        let frame = try i(s,0x70),ts = l.tState
        func guardUp() throws -> Bool { try press(s,.defend); try release(s,.defend); return true }
        if frame > 267 && frame < 283 {
            if ts == 12 || ts == 11 { return try guardUp() }
            if try dx(s,t) > 150 || dz(s,t) > 25 { return try guardUp() }
            if try facingToward(s,i(t,0x10)) { return try guardUp() }
        }
        if ts != 18 && ts != 14 {
            if ts != 12, try i(s,0x2fc) > 70, try i(s,0x308) > 320 {
                let d = try dx(s,t)
                if try (d > 50 || dz(s,t) > 10) && d < 85 && i(s,0x2fc) > i(t,0x2fc) && dz(s,t) < 35, try draw(0x55,5) == 0 { return try command(s,0xda) }
            }
            if ts != 12, try i(s,0x308) > 200 {
                let d = try dx(s,t)
                if try d > 100 && d < 370 && dz(s,t) < 60, try draw(0x56,20) == 0 { return try aimed(s,t) }
            }
        }
        if try draw(0x57,100) == 0 {
            let d = try dx(s,t)
            if d > 240 && d < 400 { return try aimed(s,t) }
        }
        if ts != 18 && ts != 14 && ts != 12, try i(s,0x308) > 200 {
            let d = try dx(s,t)
            if try d > 60 && d < 280 && dz(s,t) < 60, try draw(0x58,15) == 0, try facingToward(s,i(t,0x10)) { return try command(s,0xdb) }
        }
        guard frame >= 255 && frame <= 261 else { return false }
        let f = try facing(s),sx = try i(s,0x10),tx = try i(t,0x10)
        if f == 0, try sx > tx &+ 120 || sx > g(0x44f604) &+ -30 { return try guardUp() }
        if f == 1, sx < tx &- 120 || sx < 30 { return try guardUp() }
        let tz = try i(t,0x18),sz = try i(s,0x18)
        if abs(tz &- sz) > 70 { return try guardUp() }
        if try g(0x44f608) == 1 { return try guardUp() }
        let toward = try facingToward(s,i(t,0x10))
        if toward ? tz > sz : tz < sz { try press(s,.down) } else { try press(s,.up) }
        return false
    }

    /// 40498d..404c05 (Chiyo).
    mutating func chiyo8(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        let ts = l.tState
        if ts != 13 {
            if try i(s,0x308) > 200, try dx(s,t) < 400, try dz(s,t) < 170, try draw(0x59,250) == 0 { return try aimed(s,t) }
            if ts != 14, try i(s,0x308) > 200 {
                let d = try dx(s,t)
                if try d > 60 && d < 280 && dz(s,t) < 65, try draw(0x5a,15) == 0 { return try aimed(s,t) }
            }
        }
        if ts != 14, try i(s,0x308) > 320 {
            let d = try dx(s,t)
            let close = try d <= 50 && dz(s,t) <= 7
            if !close || ts == 13, d < 125, try dz(s,t) < 25, try draw(0x5b,3) == 0, try facingToward(s,i(t,0x10)) { return try command(s,0xda) }
        }
        guard try draw(0x5c,50) == 0, try i(s,0x98) == 0, try i(s,0x308) > 200, try dx(s,t) > 200 else { return false }
        if try dz(s,t) > 50 { return try command(s,0xdb) }
        return false
    }

    /// Shared opening of Sasuke/Deidara (404c70/404e1a): facing 0 with the
    /// target on the right sets 0xd7; facing 1 with it on the left returns 1
    /// without a command (the EXE skips the store); otherwise continue.
    mutating func lunge(_ s: Int,_ t: Int) throws -> Bool? {
        let f = try facing(s),sx = try i(s,0x10),tx = try i(t,0x10)
        if f == 0 && tx > sx { return try command(s,0xd7) }
        if f == 1 && tx < sx { return true }
        return nil
    }
    /// Dash strike (404d2e/404ec2): ftol(vx) − x + target x within reach.
    mutating func dash(_ s: Int,_ t: Int,reach: Int32,mp: Int32?) throws -> Bool {
        let tx = try i(t,0x10)
        guard try abs(ftol(s,0x40) &- i(s,0x10) &+ tx) < reach, try dz(s,t) < 7 else { return false }
        if let mp { guard try i(s,0x308) > mp else { return false } }
        let f = try facing(s),sx = try i(s,0x10)
        if (f == 0 && sx < tx) || (f == 1 && sx > tx) { return try command(s,0xd6) }
        return false
    }
    func frameField(_ a: Int,_ o: Int) throws -> Int32 {
        let n = try object(a),f = try i(a,0x70)
        guard objects[n].frameStorage.indices.contains(Int(f)) else { throw error("Character-AI Frame binding") }
        return try objects[n].frameStorage[Int(f)].integer(at: o,as: Int32.self)
    }

    /// 404c05..404dae (Sasuke).
    mutating func sasuke11(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        if try i(s,0x308) > 150, try dx(s,t) < 280, try dz(s,t) < 30, try draw(0x5d,10) == 0, let done = try lunge(s,t) { return done }
        if try frameField(s,0x2c) == 290 && i(t,0x14) < 0 { try release(s,.jump); try press(s,.jump) }
        if try draw(0x5e,5) == 0 || l.tState == 16 || l.tState == 8 { if try dash(s,t,reach: 100,mp: 200) { return true } }
        return false
    }

    /// 404dae..40513a (Deidara). The ally-distance and 0xda stores do not end the call.
    mutating func deidara10(_ s: Int,_ t: Int,slot: Int,_ l: Locals) throws -> Bool {
        let ts = l.tState
        if try i(s,0x308) > 100, try dx(s,t) < 280, try dz(s,t) < 25, try draw(0x5f,10) == 0, let done = try lunge(s,t) { return done }
        if try i(s,0x70) == 271 && i(t,0x14) < 0 && ts == 12 { return try command(s,0xd6) }
        if try draw(0x60,10) == 0 || ts == 16 || ts == 8 { if try dash(s,t,reach: 80,mp: nil) { return true } }
        if try i(s,0x308) > 200 {
            let d = try dx(s,t)
            if try d > 60 && d < 280 && dz(s,t) < 65 {
                if try draw(0x61,15) == 0 { return try aimed(s,t) }
                if try draw(0x62,4) == 0 {
                    if ts == 16 || ts == 8 { return try aimed(s,t) }
                    if try ts == 12 && i(t,0x14) < -40 { return try aimed(s,t) }
                }
            }
        }
        let hp = try i(s,0x2fc)
        if try hp < 250 && hp < i(t,0x2fc) &+ 50, try draw(0x63,20) == 0, try i(s,0x308) > 75 {
            var farthest: Int32 = -1,found = false
            for k in 0..<400 where k != slot {
                guard try active(k) != 0 else { continue }
                let a = try index(k)
                guard try type(a) == 0, try i(a,0x364) == i(s,0x364), try i(a,0x2fc) > i(t,0x2fc) else { continue }
                let d = try dz(s,a) &+ dx(s,a)
                if d > farthest { farthest = d; found = true }
            }
            if try found && farthest > 300 && i(s,0x98) == 0 { try byte(s,0xdb,3) }
        }
        if try i(s,0x2fc) > i(t,0x2fc), try draw(0x64,70) == 0, try i(s,0x308) > 500 { try byte(s,0xda,3) }
        return false
    }

    /// 40513a..405311 (Itachi).
    mutating func itachi9(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        let ts = l.tState
        if try draw(0x65,10) == 0 || ts == 16 || ts == 8 {
            let tx = try i(t,0x10)
            if try abs(ftol(s,0x40) &- i(s,0x10) &+ tx) < 120, try dz(s,t) < 7 {
                let f = try facing(s),sx = try i(s,0x10)
                if (f == 0 && sx < tx) || (f == 1 && sx > tx) { return try command(s,0xd7) }
            }
        }
        if ts != 18 && ts != 14 && ts != 12, try i(s,0x308) > 200 {
            let d = try dx(s,t)
            if try d > 75 && d < 370 && dz(s,t) < 60, try draw(0x66,13) == 0 { return try aimed(s,t) }
        }
        if try draw(0x67,i(t,0x2fc)/4 &+ 40) == 0 {
            let d = try dx(s,t)
            if d > 150 && d < 400 { return try aimed(s,t) }
        }
        if l.nearest38 < 10000, try draw(0x68,30) == 0, try i(s,0x308) > 150 { return try command(s,0xd6) }
        return false
    }

    /// 405311..405498 (Hunter).
    mutating func hunter32(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        let ts = l.tState
        if ts != 18 && ts != 14 && ts != 12, try i(s,0x308) > 200, try dx(s,t) < 270, try dz(s,t) < 60,
           try draw(0x69,60) == 0 { return try aimed(s,t) }
        if try draw(0x6a,i(t,0x2fc)/4 &+ 40) == 0 {
            let d = try dx(s,t)
            if d > 150 && d < 400 { return try aimed(s,t) }
        }
        if try dx(s,t) < 150, try dz(s,t) < 40, try draw(0x6b,15) == 0 { return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5) }
        return false
    }

    /// 405550..405761 (Kidomaru).
    mutating func kidomaru34(_ s: Int,slot: Int,_ l: Locals) throws -> Bool {
        if try draw(0x6d,10) == 0, try i(s,0x308) > 350, try wounded(s,margin: 70) { return try command(s,0xdb) }
        return try healAlly(s,slot: slot,l)
    }

    /// 405761..405913 (Pein). Pressing attack at target frames 263/264 continues.
    mutating func pein50(_ s: Int,_ t: Int) throws -> Bool {
        if try draw(0x6e,7) == 0 {
            let d = try dx(s,t)
            if try d < 500 && d > 90 && dz(s,t) < 4 && i(s,0x308) > 150 {
                let tf = try i(t,0x70)
                if tf == 263 || tf == 264 { try release(s,.attack); try press(s,.attack) }
                else { return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5) }
            }
        }
        if try draw(0x6f,7) == 0, try dx(s,t) < 100, try dz(s,t) < 7, try i(s,0x308) > 75 { return try command(s,0xd7) }
        return false
    }

    /// 405913..40598d (Sakon).
    mutating func sakon35(_ s: Int,_ t: Int) throws -> Bool {
        if try draw(0x70,7) == 0 {
            let d = try dx(s,t)
            if try d < 650 && d > 40 && dz(s,t) < 4 && i(s,0x308) > 120 { return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5) }
        }
        return false
    }

    /// 40598d..405abc (Tayuya). After scanning slots 0..99 for a wounded
    /// teammate (itself included) the call ends even without a command.
    mutating func tayuya36(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 200, try draw(0x71,5) == 0 {
            for k in 0..<100 {
                guard try active(k) == 1 else { continue }
                let a = try index(k)
                guard try type(a) == 0, try i(a,0x364) == i(s,0x364) else { continue }
                let hp = try i(a,0x2fc),max = try i(a,0x300)
                if hp < max &- 200 || (hp < 200 && hp < max &+ -100) { return try command(s,0xda) }
            }
            return true
        }
        if try i(s,0x308) > 260, try draw(0x72,10) == 0, try dx(s,t) < 650, try dz(s,t) < 240 { return try command(s,0xd6) }
        return false
    }

    /// 405abc..405c1d (Sasuke, cursed seal).
    mutating func sasukeCS38(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 150, try draw(0x73,5) == 0 {
            let d = try dx(s,t)
            if try d < 250 && d > 130 && dz(s,t) < 10 { return try aimed(s,t) }
        }
        if try i(s,0x308) > 200, try draw(0x74,10) == 0, try dz(s,t) < 10 { return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5) }
        if try i(s,0x308) > 200, try draw(0x75,10) == 0, try dx(s,t) > 200 || dz(s,t) < 250 { return try command(s,0xda) }
        return false
    }

    /// 405c1d..405d0d (sand creature).
    mutating func sand39(_ s: Int,_ t: Int) throws -> Bool {
        if try i(s,0x308) > 100, try draw(0x76,3) == 0, try dx(s,t) < 120, try facingToward(s,i(t,0x10)), try dz(s,t) < 10 {
            return try command(s,0xd7)
        }
        if try i(s,0x308) > 100, try draw(0x77,7) == 0, try dx(s,t) < 250, try dz(s,t) < 10 {
            return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5)
        }
        return false
    }

    /// 405d0d..405fc2 (Kyubi). The claw branch ends the call even when the
    /// target is not on the right; the dash needs chakra below 100.
    mutating func kyubi52(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        if l.tState == 3, try i(s,0x308) > 125, try draw(0x78,10) == 0, try dx(s,t) < 120, try dz(s,t) < 10 { return try command(s,0xdc) }
        if try i(s,0x308) > 125, try draw(0x7b,5) == 0, try dx(s,t) < 100, try dz(s,t) < 30 {
            if try i(t,0x10) > i(s,0x10) { try byte(s,0xda,3) }
            return true
        }
        if try i(s,0x308) > 125, try draw(0x7c,14) == 0, try dx(s,t) < 700, try dz(s,t) < 150 {
            return try command(s,try i(t,0x10) > i(s,0x10) ? 0xd4 : 0xd5)
        }
        if try i(s,0x308) > 125, try draw(0x7d,5) == 0, try dz(s,t) < 20 { return try aimed(s,t) }
        if try draw(0x7e,5) == 0 || l.tState == 16 || l.tState == 8 {
            let tx = try i(t,0x10)
            if try abs(ftol(s,0x40) &- i(s,0x10) &+ tx) < 100, try dz(s,t) < 7, try i(s,0x308) < 100, try facingToward(s,tx) {
                return try command(s,0xd6)
            }
        }
        return false
    }

    /// 405fc2..40618b (Sasori).
    mutating func sasori51(_ s: Int,_ t: Int) throws -> Bool {
        let frame = try i(s,0x70)
        if frame > 265 && frame < 280, try dz(s,t) > 13 || type(t) != 0 { try release(s,.defend); try press(s,.defend); return true }
        if try i(s,0x308) > 300, try draw(0x7f,10) == 0, try dx(s,t) < 300, try dz(s,t) < 200 { return try command(s,0xda) }
        if try i(s,0x308) > 300, try draw(0x80,10) == 0, try dx(s,t) < 950 { return try command(s,0xd6) }
        if try draw(0x81,5) == 0, try i(s,0x308) > 250 {
            let d = try dx(s,t)
            if try d < 1200 && d > 40 && dz(s,t) < 13 { return try aimed(s,t) }
        }
        return false
    }

    /// 405498..405550 (naruto_clone).
    mutating func clone33(_ s: Int,_ t: Int,_ l: Locals) throws -> Bool {
        if try draw(0x6c,5) == 0 || l.tState == 16 || l.tState == 8 {
            let tx = try i(t,0x10)
            if try abs(ftol(s,0x40) &- i(s,0x10) &+ tx) < 60, try dz(s,t) < 7, try i(s,0x308) > 150 {
                let f = try facing(s),sx = try i(s,0x10)
                if (f == 0 && sx < tx) || (f == 1 && sx > tx) { return try command(s,0xd6) }
            }
        }
        return false
    }
}
