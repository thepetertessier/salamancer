Z = 4
dir = {
    right = 0,
    left = 1,
    up = 2,
    down = 3
}
clr = {
    black = 0,
    dark_blue = 1,
    purple = 2,
    dark_green = 3,
    brown = 4,
    grey = 5,
    light_grey = 6,
    white = 7,
    red = 8,
    orange = 9,
    yellow = 10,
    green = 11,
    blue = 12,
    light_purple = 13,
    pink = 14,
    peach = 15
}

function debug(text)
    printh(text, 'debug.txt')
end

function _rect(x,y,w,h)
    return {x=x, y=y, w=w, h=h}
end

function _sr(x, y, rect)
    return _rect(x+rect.x, y+rect.y, rect.w, rect.h)
end

function get_hit_box(entity)
    return _sr(entity.x, entity.y, entity.hit_box)
end

function get_hurt_box(entity)
    return _sr(entity.x, entity.y, entity.hurt_box)
end

function rect_overlap(r1, r2)
    return r1.x < r2.x + r2.w and
           r1.x + r1.w > r2.x and
           r1.y < r2.y + r2.h and
           r1.y + r1.h > r2.y
end

function hits(predator, prey)
    return rect_overlap(get_hit_box(predator), get_hurt_box(prey))
end

function limit_speed(speed, max_speed)
    return mid(-max_speed, speed, max_speed)
end

--from the carpathian
--by jeff givens
function explode(expx,expy,isblue)	
	local mypx={}
	mypx.x=expx
	mypx.y=expy
	mypx.sx=0
	mypx.sy=0
	mypx.age=13
	mypx.size=9
	mypx.maxage=8
    mypx.blue=isblue
 
	add(parts,mypx)
    
    for i=1,40 do
        local mypx={}
        mypx.x=expx
        mypx.y=expy
        mypx.sx=(rnd()-0.5)*2.5
        mypx.sy=(rnd()-0.5)*2.5
        mypx.age=rnd(5)
        mypx.size=1+rnd(2)
        mypx.maxage=15+rnd(15)
        mypx.blue=isblue
        add(parts,mypx)
    end
    
    for i=1,40 do
        local mypx={}
        mypx.x=expx
        mypx.y=expy
        mypx.sx=(rnd()-0.5)*1.5
        mypx.sy=(rnd()-0.5)*1.5
        mypx.age=rnd(5)
        mypx.size=1+rnd(2)
        mypx.maxage=15+rnd(15)
        mypx.blue=isblue
        mypx.spark=true
        add(parts,mypx)
    end
    
end

function sspr_based_on_s_arrays(frame, sx, sy, sw, sh, x, y, flip)
    sspr(sx[frame], sy[frame], sw[frame], sh[frame], x, y, sw[frame], sh[frame], flip)
end

function get_pl_damage()
    if pl_is_dashing() then
        return min(max(1.7,abs(pl.dx/2),abs(pl.dx/2)),2)
    end
    return min(max(0.6,abs(pl.dx/4),abs(pl.dx/4)),1)
end

function make_enemy(enemy_constants, flip, x, y)
    --enemy constants must define:
        --init (with sx,sy,sw,sh)
        --update (movement)
    local enemy = {}
    enemy.flip = flip
    enemy.x = x or (enemy.flip and map_start or map_end)
    enemy.y = y
    enemy.frame = 1
    enemy.life = 1
    enemy.damage = 1
    enemy.max_hurt_t = 60
    enemy.hurt_t = -1
    enemy.hurt = function(this, damage, sound)
        hurt_enemy_if_vuln(this, damage, sound)
    end
    enemy.xp = 15
    enemy_constants.init(enemy)
    enemy.max_frame = #enemy.sx
    enemy.last_frame_time = 0
    enemy.update = function(this)
        update_frame(this)
        enemy_constants.update(this)
        this.hurt_box = _rect(0,0,this.sw[this.frame],this.sh[this.frame])
        this.hit_box = this.hurt_box
        if hits(pl, this) then
            if pl_can_hit() then
                this:hurt(get_pl_damage(), this.hurt_sound)
            end
        end
        if this.life <= 0 then
            explode(this.x+this.sw[this.frame]/2, this.y+this.sh[this.frame]/2, false)
            sfx(choose_random({9,15}),2)
            score += this.xp
            del(enemies, this)
        end
        if hits(this, salamancer) then
            explode(this.x+this.sw[this.frame]/2, this.y+this.sh[this.frame]/2, true)
            salamancer:hurt(this.damage)
            del(enemies, this)
        end
        if this.hurt_t >= 0 then
            if this.hurt_t >= this.max_hurt_t then
                this.hurt_t = -1 --no more hurt
            else
                this.hurt_t+=1
            end
        end
    end
    enemy.draw = function(this)
        if enemy_constants.pal_swap then
            enemy_constants.pal_swap(this)
        end
        if this.hurt_t >= 0 then
            if (this.hurt_t % 8) < 4 then
                --blink
                pal(clr.black, clr.white)
            end
        end
        sspr_based_on_s_arrays(this.frame, this.sx, this.sy, this.sw, this.sh, this.x, this.y, this.flip)
        reset_pal()
        if enemy_constants.draw then
            enemy_constants.draw(this)
        end
    end
    add(enemies, enemy)
end

function draw_health_bar(enemy)
    local h = 3
    local padding = 1
    local percent = enemy.life / enemy.max_life
    local w = enemy.sw[1]
    local x = enemy.x
    local y = enemy.y - w/2
    rectfill(x, y, x + w, y + h, clr.black)
    rectfill(x + padding, y + padding, x + (w * percent) - padding, y + h - padding, clr.red)
end

function update_frame(obj)
    --must specify obj.max_frame
    obj.frame_duration = obj.frame_duration or 9
    obj.t = obj.t or 0
    obj.frame = obj.frame or 1
    obj.t += 1
    if obj.t % obj.frame_duration == 0 then
        obj.frame = (obj.frame % obj.max_frame) + 1
        local sound = obj.sfx and obj.sfx[obj.frame]
        if sound then
            sfx(sound,2)
        end
    end
end

function hurt_enemy_if_vuln(enemy, damage, sound)
    sound = sound or 17
    if enemy.hurt_t >= 0 then
        --we are already hurting, hence invulnerable
        return
    end
    enemy.hurt_t = 0
    enemy.life -= damage
    -- sfx(sound)
end

-- enemies
function set_ys_from_yo(enemy)
    for frame = 1,#enemy.yo do
        enemy.ys[frame] = enemy.y_base + enemy.yo[frame]
    end
end

function make_froglet_constants()
    froglet = {
        init = function(this)
            this.sx=split(" 0, 0,11,24, 0,10")
            this.sy=split(" 0, 0, 1, 0, 6, 6")
            this.sw=split("11,11,13, 8,11,13")
            this.sh=split(" 6, 6, 5,15,11, 10")
            this.speeds=split("0,0,0,1,0.3,0.1")
            this.yo=split("0,0,1,-10,-10,-5")
            this.sfx={[4]=19}
            this.y_base = 128-8-this.sh[1]
            this.ys={}
            this.life = 0.5
            this.primary_col = clr.dark_green
            this.damage = 1
            this.xp = 10
            set_ys_from_yo(this)
        end,
        update = function(this)
            local speed = this.speeds[this.frame]
            this.x += speed * (this.flip and 1 or -1)
            this.y = this.ys[this.frame]
        end,
        hurt = function(this, damage)
            this.life -= damage
        end
    }
    return froglet    
end

function make_pink_froglet_constants()
    local froglet_constants = make_froglet_constants()
    local pink_froglet = deep_copy_table(froglet_constants)
    pink_froglet.init = function(this)
        froglet_constants.init(this)
        this.primary_col = clr.pink
        -- this.yo={0,0,1,-10,-55,-5}
        -- set_ys_from_yo(this)
        this.y = this.y_base
        this.sx=      split(" 0,11, 24, 24,  0,  0, 10, 10")
        this.sy=      split(" 0, 1,  0,  0,  6,  6,  6,  6")
        this.sw=      split("11,13,  8,  8, 11, 11, 13, 13")
        this.sh=      split(" 6, 5, 15, 15, 11, 11, 10, 10")
        this.speeds=  split(" 0, 0,0.1,0.3,0.5,0.5,0.3,0.1")
        this.y_speeds=split(" 0, 0, -6, -3,-.5,0.5,  3,  6")
    end
    pink_froglet.pal_swap = function(this)
        pal(clr.dark_green, clr.pink)
        pal(clr.light_grey, clr.peach)
    end
    pink_froglet.update = function(this)
        local speed = this.speeds[this.frame]
        this.x += speed * (this.flip and 1 or -1)
        this.y += this.y_speeds[this.frame]
    end
    return pink_froglet
end

function make_base_toad_constants()
    local toad = {
        init = function(this)
            this.sx=    split(" 0,24,49, 75,101, 0,35,58, 0, 0, 0, 0")
            this.sy=    split("45,44,42, 25, 25,69,64,71,45,45,45,45")
            this.sw=    split("24,25,26, 26, 25,35,23,28,24,24,24,24")
            this.sh=    split("19,20,22, 28, 29,18,23,16,19,19,19,19")
            this.speeds=split(" 0, 0, 0,1.5, .5,.1, 0, 0, 0, 0, 0, 0")
            this.sfx={[4]=20}
            this.y_base = 128-5-this.sh[1]
            this.ys={}
            this.damage = 2
            this.life = 4
            this.max_life = 4
            this.primary_col = clr.brown
            this.push_back_dx = 0.5
            this.hurt_sound = 18
            this.xp = 40
        end,
        update = function(this)
            local hurt_t = this.hurt_t or -1
            if hurt_t == 1 then
                this.push_back_dx = mid(0.1, abs(pl.dx/3), 5)
                pl.dx *= -2
                pl.dy *= -1
            end
            local dx
            if hurt_t >= 0 and hurt_t < 10 then
                dx = -this.push_back_dx
            else
                dx = this.speeds[this.frame]
            end
            dx = this.flip and dx or -dx
            this.x += dx
        end,
        draw = function(this)
            draw_health_bar(this)
        end
    }
    return toad
end

function make_toad_constants()
    local toad_constants = make_base_toad_constants()
    local toad = deep_copy_table(toad_constants)
    toad.init = function(this)
        toad_constants.init(this)
        for frame = 1,#this.sy do
            this.ys[frame] = (this.y_base + this.sy[frame] - this.sy[1])
            if this.sy[frame] > 60 then
                this.ys[frame] -= 25
            end
        end
        for i=9,12 do
            this.ys[i] -= 2
        end
    end
    toad.update = function(this)
        toad_constants.update(this)
        this.y = this.ys[this.frame]
    end
    return toad
end

function make_pink_toad_constants()
    local toad_constants = make_base_toad_constants()
    local pink_toad = deep_copy_table(toad_constants)
    pink_toad.init = function(this)
        toad_constants.init(this)
        this.primary_col = clr.pink
        -- this.yo={0,0,1,-10,-55,-5}
        -- set_ys_from_yo(this)
        this.y = this.y_base -2
        this.sx=      split("  0, 24, 49, 75, 75,101,101,  0, 35, 58,  0,  0,  0,  0")
        this.sy=      split(" 45, 44, 42, 25, 25, 25, 25, 69, 64, 71, 45, 45, 45, 45")
        this.sw=      split(" 24, 25, 26, 26, 26, 25, 25, 35, 23, 28, 24, 24, 24, 24")
        this.sh=      split(" 19, 20, 22, 28, 28, 29, 29, 18, 23, 16, 19, 19, 19, 19")
        this.speeds=  split("  0,  0,  0,1.5, .3, .1, .1,  0,  0,  0,  0,  0,  0,  0")
        this.y_speeds=split("  0,  0, -6, -3,-.5, .5,  3,  6,  0,  0,  0,  0,  0,  0")
        this.max_life = 3
        this.life = this.max_life
        this.xp = 50
    end
    pink_toad.pal_swap = function(this)
        pal(clr.brown, clr.pink)
        -- pal(clr.light_grey, clr.peach)
    end
    pink_toad.update = function(this)
        toad_constants.update(this)
        local speed = this.speeds[this.frame]
        -- this.x += speed * (this.flip and 1 or -1)
        this.y += this.y_speeds[this.frame]
    end
    return pink_toad
end

function make_glider_constants()
    local glider = {
        init = function(this)
            this.sx={83,103,83,103,83,103}
            this.sy={ 0,  0, 8,  8,16, 16}
            this.sw={20,20,20, 20, 20, 20}
            this.sh={ 8, 8, 8,  8,  8, 8}
            this.speed = 0
            this.max_speed = 0.5
            this.accel = this.flip and 0.005 or -0.005
            this.primary_col = clr.pink
            this.life = 0.5
            this.damage = 1
            sfx(22,2)
        end,
        update = function(this)
            this.speed += this.accel
            this.speed = limit_speed(this.speed, this.max_speed)
            this.x += this.speed
            this.y += abs(this.speed)
        end
    }
    return glider
end

function make_pilot_constants()
    local pilot = {
        init = function(this)
            this.sx={32,49,66,32,49,66}
            this.sy={ 0, 0, 0, 9, 9, 9}
            this.sw={17,17,17,17,17,17}
            this.sh={ 9, 9, 9, 8, 8, 8}
            this.ys={20,20,20,21,21,21}
            this.speed = 0.7
            this.max_shoot = 60
            this.shoot = 0
            this.primary_col = clr.grey
            this.life = 0.5
            this.damage = 0
            this.xp = 30
            sfx(21,2)
        end,
        update = function(this)
            local speed = this.speed
            this.x += speed * (this.flip and 1 or -1)
            this.y = this.ys[this.frame]
            if this.x < -20 or this.x > 128*2 + 20 then
                del(enemies, this)
            end
            this.shoot = (this.shoot + 1) % this.max_shoot
            if this.max_shoot - this.shoot <= 9 and
            (this.max_shoot - this.shoot) % 3 == 0 then
                local x = this.flip and this.x+17 or this.x-3
                make_bullet(x,this.y+3,this.flip)
            end
        end
    }
    return pilot    
end

function make_pink_pilot_constants()
    local pilot_constants = make_pilot_constants()
    local pink_pilot = deep_copy_table(pilot_constants)
    pink_pilot.init = function(this)
        pilot_constants.init(this)
        this.primary_col = clr.pink
    end
    pink_pilot.pal_swap = function(this)
        pal(clr.grey, clr.pink)
        pal(clr.light_purple, clr.red)
    end
    pink_pilot.update = function(this)
        pilot_constants.update(this)
        if abs(30 - this.x) <= abs(this.speed)/2 and rnd(1) < 1 then
            make_enemy(glider, true, this.x, 8)
        end
        if abs(200 - this.x) < abs(this.speed)/2 and rnd(1) < 1 then
            make_enemy(glider, false, this.x, 8)
        end
    end
    return pink_pilot
end

function make_charger_constants()
    local charger = {
        init = function(this)
            this.sx=    {  0, 15, 30, 46}
            this.sy=    {118,120,119,118}
            this.sw=    { 11, 11, 13, 14}
            this.sh=    {  9,  8,  7,  8}
            this.speeds={0.2,  0,  2,0.5}
            this.ys=    {109,112,110,109}
            this.primary_col = clr.orange
            this.life = 0.5
            this.damage = 1
            this.sfx={[2]=19}
            this.xp = 20
        end,
        update = function(this)
            local speed = this.speeds[this.frame]
            this.x += speed * (this.flip and 1 or -1)
            this.y = this.ys[this.frame]
        end
    }
    return charger
end

function make_bullet(x,y,flip)
    local bul = {
        x=x,y=y,w=6,h=6,
        sx={ 88, 94,100},
        speed_x = flip and 1 or -1,
        speed_y = 1.2,
        max_frame = 3,
        hit_box = _rect(1,1,4,4),
        update = function(this)
            this.x += this.speed_x
            this.y += this.speed_y
            if this.y > 128 then
                del(bullets, this)
            end
            if hits(this, pl) then
                stun_player()
                del(bullets, this)
            end
            update_frame(this)
        end,
        draw = function(this)
            sspr(this.sx[this.frame],120,this.w,this.h,this.x,this.y)
        end
    }
    add(bullets, bul)
end

function make_torch(x,y)
    local torch = {
        x=x,y=y,sw=5,sh=21,t=0,frame=1,max_frame=2,
        frame_duration=13,
        update = function(this)
            update_frame(this)
        end,
        draw = function(this)
            local sx = this.frame == 1 and 78 or 83
            sspr(sx, 99, this.sw, this.sh, this.x, this.y)
        end,
    }
    return torch
end

function reset_pal()
    pal()
    palt(clr.black, false)
    palt(clr.green, true)
end

function _init()
    poke(0x5f5c, 255) --don't allow a bounce spam

    -- make green transparent instead of black
    reset_pal()

    -- game settings
    ceil_y = 8
    floor_y = 128 - ceil_y
    map_start = 0
    map_end = 256
    wall_left = map_start + 8
    wall_right = map_end - 8
    rumble = 0
    position_history_length = 10

    --enemies
    froglet = make_froglet_constants()
    toad = make_toad_constants()
    glider = make_glider_constants()
    pilot = make_pilot_constants()
    pink_froglet = make_pink_froglet_constants()
    pink_toad = make_pink_toad_constants()
    charger = make_charger_constants()
    pink_pilot = make_pink_pilot_constants()

    high_score = 0
    restart_game(-2)
end

function restart_game(lvl)
    current_lvl = lvl
    initial_state = make_dialogue(lvl)
    --player settings (constant)
    ps = {
        max_charge_time = 1 * 30,
        max_dash_time = 15,
        min_dash_time = 10,
        auto_release_time = 1.5 * 30,
        max_brake_time = 20,
        accel = {
            default = 0.5,
            dash = 2,
            braking = 0.3,
        },
        max_speed = {
            default = 2,
            dash = 3.5,
            braking = 1,
        },
        default_frtn_vert = -0.95,
        default_frct_horz = -0.9,
    }

    pl = {
        radius = 4,
        x = 127,
        y = 60,
        dx = 0,
        dy = 0,
        bounce_frtn_vert = ps.default_frtn_vert,
        bounce_frct_horz = ps.default_frct_horz,
        max_speed = 2,
        charge_time = -1,
        dash_time = -1,
        brake_time = -1,
        dash_end_time = ps.max_dash_time,
        last_directions = {
            [dir.right] = -1,
            [dir.left] = -1,
            [dir.up] = 0,
            [dir.down] = -1
        },
        max_stun_time = 60,
        stun_time = -1,
        col = clr.yellow,
        rim_col = clr.orange,
        history = {}
    }
    pl.w = pl.radius*2-1
    pl.hit_box = _rect(0,0,pl.w,pl.w)
    pl.hurt_box = _rect(1,1,pl.w-2,pl.w-2)

    game = make_game(initial_state)

    -- salamancer costumes
    scs = {
        idle = 1,
        hurt = 2,
        charging = 3,
        release = 4,
    }

    salamancer = {
        x = 118,
        y = 98,
        flip = false,
        max_life = 5,
        max_hurt_time = 20, --how long until can be hurt again
        hurt_time = -1,
        frame = 1,
        hurt_box = _rect(5,2,10,13),
        costume = scs.idle,
        blink_color = clr.blue,
        [scs.idle] = {
            frame_duration = 20,
            max_frame = 2,
            sx = { 0,16,},
            sy = {17,17,},
            sw = {16,22,},
            sh = {22,21,},
            xo = { 0,-5,},
            yo = { 0, 0,},
        },
        [scs.hurt] = {
            frame_duration = 100,
            max_frame = 1,
            sx = {38},
            sy = {17},
            sw = {24},
            sh = {24},
            xo = {-5},
            yo = {0},
        },
        [scs.charging] = {
            frame_duration = 100,
            max_frame = 1,
            sx = {76},
            sy = {54},
            sw = {25},
            sh = {14},
            xo = {-5},
            yo = {10},
        },
        [scs.release] = {
            max_frame = 4,
            frame_duration = 12,
            sx = { 0,29,60},
            sy = {94,88,90},
            sw = {29,20,17},
            sh = {19,23,22},
            xo = {0,-10, 0},
            yo = {0,  0, 0},
        },
        change_costume = function(this, c)
            this.t = 0
            this.frame = 1
            this.costume = c
        end,
        update_costume = function(this)
            if this.hurt_time >= 0 then
                --we are hurting; what else matters?
                return
            end
            if (pl.charge_time == 0) then
                this:change_costume(scs.charging)
            elseif (pl.dash_time == 0) then
                this:change_costume(scs.release)
            elseif pl.dash_time >= 0 and this.frame >= 4
            or pl.dash_time >= pl.dash_end_time-1 then
                this:change_costume(scs.idle)
            end
        end,
        update = function(this)
            if this.life <= 0 then
                this:die()
            end
            this:update_costume()
            if this.hurt_time >= 0 then
                if this.hurt_time >= this.max_hurt_time then
                    --stop hurting
                    this:change_costume(scs.idle)
                    this.hurt_time = -1
                else
                    this.hurt_time += 1
                end
            end
            local c = salamancer.costume
            this.frame_duration = this[c].frame_duration
            this.max_frame = this[c].max_frame
            local center_x = 128
            if (this.flip and (pl.x > center_x + 10))
            or ((not this.flip) and (pl.x <= center_x - 10)) then
                this.flip = not this.flip
            end
            update_frame(this)

            --gradually heal
            if this.life < this.max_life then
                this.life += 0.0005
            end
        end,
        draw = function(this)
            local c = salamancer.costume
            this.blink_color = clr.blue
            if (c != scs.idle) and this.t % 8 < 4 then
                --blink
                this.blink_color = c == scs.hurt and clr.pink or clr.peach
                pal(clr.blue, this.blink_color)
            end
            local x = this.x
            local y = this.y
            if this[c].xo[this.frame] then
                x += this[c].xo[this.frame]
            end
            if this[c].yo[this.frame] then
                y += this[c].yo[this.frame]
            end
            sspr_based_on_s_arrays(this.frame, this[c].sx, this[c].sy, this[c].sw, this[c].sh, x, y, this.flip)
            reset_pal()
        end,
        hurt = function(this, damage)
            if this.hurt_time == -1 then
                this:change_costume(scs.hurt)
                this.hurt_time = 0
                this.life -= damage
                sfx(10)
            end
        end,
        die = function(this)
            restart_game(current_lvl)
        end
    }
    salamancer.life = salamancer.max_life
    for c in all(scs) do
        --get the real xo, yo value to draw
        for frame in 1,salamancer[c].max_frame do
            salamancer[c].xo[frame] += salamancer.x
        end
    end

    flash_bang = {
        x=pl.x, y=pl.y
    }

    indicator_arrow_t = 0
    embers = {}
    enemies = {}
    torches = {make_torch(64-2, 40), make_torch(64*3-2, 40)}
    bullets = {}
    parts = {}
    spawners = {}
    score = 0
end

function pl_can_hit()
    return pl.stun_time == -1
end

function make_ember(x,y,col,radius)
	local ember = {
		x=x,y=y,
		frames=1,
		col=col,
		time=0, max_time = 8+rnd(4),
		dx = 0, dy = 0,
		gravity = 0,
        radius=radius
	}
	if (#embers < 512) then
		add(embers,ember)
	end
	return ember
end

function move_ember(ember)
	if (ember.time > ember.max_time) then
		del(embers, ember)
	end
	
	ember.x += ember.dx
	ember.y += ember.dy
	ember.dy += ember.gravity
	ember.time += 1
end

function draw_ember(ember)
    circfill(ember.x, ember.y, ember.radius, ember.col)
end


function pl_is_charging()
    return pl.charge_time >= 0
end
function pl_is_dashing()
    return pl.dash_time >= 0
end
function pl_is_braking()
    return pl.brake_time >= 0
end

function accelerate_dx(dx, accel, max_speed, go_right, go_left)
    go_right = go_right or btn(➡️)
    go_left = go_left or btn(⬅️)
    if go_right then dx += accel end
    if go_left then dx -= accel end
    return limit_speed(dx, max_speed)
end

function accelerate_dy(dy, accel, max_speed, go_down, go_up)
    go_down = go_down or btn(⬇️)
    go_up = go_up or btn(⬆️)
    if go_down then dy += accel end
    if go_up then dy -= accel end
    return limit_speed(dy, max_speed)
end

function make_embers(colors, intensity)
    for i=1,3 do
        if intensity > rnd(100) then
            local radius, offset
            if intensity >= 50 then
                radius = 2
                offset = rnd(0.6)-0.3
            else
                radius = 1
                offset = rnd(2.4)-1.2
            end
            local ember = make_ember(
                pl.x+pl.dx*i/2, 
                pl.y+pl.dy*i/2 - 0.5,
                choose_random(colors),
                radius
            )
            ember.dx = -pl.dx*0.1
            ember.dy = -i/4
            ember.x += offset
            ember.y += offset
        end
    end
end

function charge_dash()
    pl.charge_time += 1

    if pl.charge_time == ps.max_charge_time then
        sfx(5,3)
    end

    -- Auto-release charge after max time
    if pl.charge_time >= ps.auto_release_time then
        release_dash()
    end

    -- Release the charge if the button is released
    if not btn(❎) then
        release_dash()
    end

    make_embers({clr.white, clr.black, clr.light_grey}, 20)
end

function release_dash()
    local mega = pl.charge_time >= ps.max_charge_time
    sfx(mega and 0 or 1,3)
    sfx(mega and 3 or 2)
    pl.dash_end_time = min((pl.charge_time / ps.max_charge_time) * ps.max_dash_time, ps.max_dash_time)
    pl.dash_end_time = max(pl.dash_end_time, ps.min_dash_time)
    pl.dash_time = 0

    -- stop charging
    pl.charge_time = -1
end

function choose_random(array)    
    local random_index = flr(rnd(#array)) + 1
    return array[random_index]
end

function perform_dash()
    pl.dash_time += 1

    if pl.dash_time >= pl.dash_end_time then
        pl.dash_time = -1 --end dash
        pl.brake_time = 0 --start braking
    end

    -- Move with a speed boost
    -- if any of the arrows are non-nil, then those arrows are also the directions we will go in
        -- otherwise, we go in the last direction(s) held
    local go_right = btn(➡️) or pl.last_directions[dir.right] >= 0
    local go_left = btn(⬅️) or pl.last_directions[dir.left] >= 0
    local go_up = btn(⬆️) or pl.last_directions[dir.up] >= 0
    local go_down = btn(⬇️) or pl.last_directions[dir.down] >= 0
    local max_speed = min(ps.max_speed.dash + (pl.dash_end_time-ps.min_dash_time), 5)
    if ( go_right and go_up   ) or
       ( go_right and go_down ) or
       ( go_left  and go_up   ) or
       ( go_left  and go_down )
    then
        --we're going diagonal: decrease speed to keep vector magnitude constant
        max_speed *= 0.7071068
    end
    pl.dx = accelerate_dx(pl.dx, ps.accel.dash, max_speed, go_right, go_left)
    pl.dy = accelerate_dy(pl.dy, ps.accel.dash, max_speed, go_down, go_up)

    make_embers({clr.yellow, clr.white, clr.black, clr.white, clr.white}, 40+20*(pl.dash_time/pl.dash_end_time))
end

function apply_braking()
    pl.brake_time += 1

    if pl.brake_time >= ps.max_brake_time then
        pl.brake_time = -1 --end brake
    end

    pl.dx = accelerate_dx(pl.dx, ps.accel.braking, ps.max_speed.braking)

    make_embers({clr.black, clr.red, clr.orange, clr.yellow, clr.brown}, 40)
    make_embers({clr.black}, 50)
end

function apply_stunning()
    rumble = 0
    pl.stun_time += 1
    if pl.stun_time >= pl.max_stun_time then
        pl.stun_time = -1
    end

    pl.dx = accelerate_dx(pl.dx, ps.accel.braking, ps.max_speed.braking)

    make_embers({clr.brown, clr.black}, 40)
end

function _check_expired_directions(directions)
    for direction in all(directions) do
        if pl.last_directions[direction] == 0 then
            --leeway is expired
            pl.last_directions[direction] = -1
        end
    end
end

function update_pl_last_directions()
    local leeway = 5 --how many frames until it doesn't count as held
    for k, v in pairs(pl.last_directions) do
        --decrement until 0
        if v > 0 then
            pl.last_directions[k] = v-1
        end
    end
    if btnp(⬇️) then
        pl.last_directions[dir.down] = leeway
        pl.last_directions[dir.up] = -1
        _check_expired_directions({dir.left, dir.right})
    end
    if btnp(⬆️) then
        pl.last_directions[dir.up] = leeway
        pl.last_directions[dir.down] = -1
        _check_expired_directions({dir.left, dir.right})
    end
    if btnp(⬅️) then
        pl.last_directions[dir.left] = leeway
        pl.last_directions[dir.right] = -1
        _check_expired_directions({dir.up, dir.down})
    end
    if btnp(➡️) then
        pl.last_directions[dir.right] = leeway
        pl.last_directions[dir.left] = -1
        _check_expired_directions({dir.up, dir.down})
    end
end

cam_x = 0
cam_y = 0
function set_camera(rumble)
    --simple camera
    --from https://nerdyteachers.com/Explain/Platformer/
    cam_x = mid(map_start, pl.x-64+(pl.w/2), map_end-128)
    cam_y = 0

    if rumble > 0 then
        cam_x+=rnd(rumble)-rumble/2
        cam_y+=rnd(rumble)-rumble/2
    end

    camera(cam_x,cam_y)
end

function stun_player()
    if pl.stun_time >= 0 then
        --we are already stunning
        return
    end
    pl.stun_time = 0
    pl.charge_time = -1
    pl.dash_time = -1
    pl.brake_time = -1
    pl.dx *= 0.5
    pl.dy = -2
    sfx(11,3)
end

function update_player()
    --PLAYER CONTROLS
    local friction = 0.95
    local gravity = 0.2

    update_pl_last_directions()

    -- Stun state
    if pl.stun_time >= 0 then
        apply_stunning()
    
    -- Charging state
    elseif pl_is_charging() then
        charge_dash()
        friction = 0.5*(max(ps.max_charge_time - pl.charge_time)/ps.max_charge_time)
        gravity*=(max(ps.max_charge_time - pl.charge_time)/ps.max_charge_time)

    -- Dash state
    elseif pl_is_dashing() then
        perform_dash()
        friction = 1
        gravity = 0
        rumble = 1.5*(abs(pl.dx) + abs(pl.dy))

    -- Braking state (slowing down after dashing)
    elseif pl_is_braking() then
        apply_braking()
        friction = 0.7
        gravity = 0.1
        rumble = 0

    else
        --Default state
        pl.dx = accelerate_dx(pl.dx, ps.accel.default, ps.max_speed.default)

        -- Start charging dash when holding X
        if btnp(❎) then
            pl.charge_time = 0
            sfx(4,3)
        elseif btnp(Z) then
            --bounce
            pl.dy = 8
            sfx(6,3)
        end

		if (abs(pl.dx) > 4 or abs(pl.dy) > 2) then
            make_embers({clr.black, clr.red, clr.orange, clr.yellow, clr.brown}, 30)
        end

        pl.col = clr.yellow
        pl.rim_col = clr.orange
    end

    --player movement
	if pl.x+pl.dx < wall_left+pl.radius or pl.x+pl.dx > wall_right-pl.radius then
		-- bounce on side
		pl.dx *= pl.bounce_frct_horz
	else
        pl.x += pl.dx
	end
	if pl.y+pl.dy < ceil_y+pl.radius or pl.y+pl.dy > floor_y-pl.radius then
		-- bounce on floor/ceiling
        if (abs(pl.dy) <= 5) and (pl.y+pl.dy > floor_y-pl.radius) then
            --bounce off floor
            pl.dy = 5
        end
		pl.dy *= pl.bounce_frtn_vert
        sfx(7,3)
	else
        pl.y += pl.dy
	end

    pl.dx *= friction
    pl.dy *= friction
    pl.dy += gravity

    --if they are too small, make them 0
    if abs(pl.dx) <= 0.1 then
        pl.dx = 0
    end
    if abs(pl.dy) <= 0.1 then
        pl.dy = 0
    end

    update_position_history(pl)
end
function make_phrase(text, col, end_t, char_t, rmb)
    local p = make_timed_obj()
    if rmb then
        rumble = rmb
    end
    p.col = col or clr.white
    p.current_text = text -- Assign the passed text to current_text
    p.current_char = 0
    p.char_interval = char_t or 2
    p.max_visible_t = end_t or 90
    p.visible_t = -1

    -- Text wrapping function
    p.wrap_text = function(text, max_width)
        local wrapped_lines = {}
        local current_line = ""
        
        for word in all(split(text, " ")) do
            local temp_line = current_line == "" and word or current_line.." "..word
            
            -- check if the line exceeds the max width
            if print(temp_line, 0, -12, 7, true) > max_width then
                -- add the current line to the wrapped lines
                add(wrapped_lines, current_line)
                -- start a new line with the current word
                current_line = word
            else
                current_line = temp_line
            end
        end
            
        -- add the last line to wrapped lines
        add(wrapped_lines, current_line)
        
        return wrapped_lines
    end

    -- Save the parent update function
    local parent_update = p.update

    -- Updated update function
    p.update = function(this)
        parent_update(this) -- Call parent update to track time

        if this.done then
            return
        end

        if this.visible_t == -1 then
            -- Display new characters based on char_interval
            if this.t % this.char_interval == 0 and this.current_char < #this.current_text then
                this.current_char += 1
                sfx(12) -- Play sound for new character
            elseif this.current_char >= #this.current_text then
                this.visible_t = 0 -- Start countdown to hide text
            end
        else
            -- Keep the text visible for a set amount of time
            if this.visible_t < this.max_visible_t then
                this.visible_t += 1
            else
                this.done = true -- Mark the phrase as done after max_visible_t
            end
        end
    end

    -- Updated draw function
    p.draw = function(this)
        if this.current_char > 0 or this.visible_t > 0 then
            -- Draw background box
            local x1,y1,x2,y2
            x1=cam_x+10 x2=cam_x+128-10
            y1=60       y2=100

            rectfill(x1, y1, x2, y2, 0) -- background
            rect(x1, y1, x2, y2, 7) -- border
    
            -- Extract the visible portion of the text
            local visible_text = sub(this.current_text, 1, this.current_char)
            
            -- Wrap the visible text
            local wrapped_lines = this.wrap_text(visible_text, 100) -- wraps to 100 px
    
            -- Draw the wrapped text line by line
            for i=1,#wrapped_lines do
                print(wrapped_lines[i], x1+5, y1+5 + (i-1)*6, this.col)
            end
        end
    end

    return p
end

function make_timed_obj()
    local obj = {
        t = 0,
        done = false,
        update = function(this)
            this.t += 1
        end,
        draw = function(this)
        end
    }
    return obj
end

function make_game_state()
    local state = make_timed_obj()
    state.next_state = function(this)
    end
    return state
end

function make_ending()
    local ending = make_game_state()
    return ending
end

function make_dialogue(lvl)
    music(3,0,1)
    current_lvl = lvl
    local dialogue = make_game_state()
    dialogue.lines = {{text="yay, you win!"}}
    local next_is_ending = false
    if lvl == -2 then
        dialogue.lines = {
            {text="hello, little friend!"},
            {text="thank you for responding to my summons. you could not have come at a worse time."},
            {text="i don't know why, but i,", end_t=30},
            {text="the salamancer,", col=clr.red, end_t=30},
            {text="am being invaded by frogs!"},
            {text="luckily, i have you to protect me."},
            {text="you can move by pressing ⬅️ and ➡️", col=clr.blue, end_t=120},
            {text="go on and try to kill that frog over to the right."},
        }
    elseif lvl == -1 then
        dialogue.lines = {
            {text="great job! i'm glad to have you around."},
            {text="here's another tip: you can press z to bounce straight down.", col=clr.blue, end_t=120},
            {text="it can be helpful for getting lots of frogs quickly... like those to the left!!"},
        }
    elseif lvl == 0 then
        dialogue.lines = {
            {text="phew, thanks!"},
            {text="one last thing: you can press and release ❎ to unleash a powerful dash attack.", col=clr.blue, end_t=120},
            {text="over here to the right! here's an opportunity to use it!"},
        }
    elseif lvl == 1 then
        dialogue.lines = {
            {text="way to go!"},
            {text="oh boy. it sounds like there's more coming... i hope you're ready..."}
        }
    elseif lvl == 2 then
        dialogue.lines = {
            {text="nice work!"},
            {text="oh no... do i hear planes flying in the distance??"},
            {text="if they're shooting bullets, i'll be ok - my shield protects me"},
            {text="but if you get hit, you'll be stunned, so watch out!"}
        }
    elseif lvl == 3 then
        dialogue.lines = {
            {text="wow, that was close"},
            {text="it sounds like there's some high-jumpers coming - heads up!"},
        }
    elseif lvl == 4 then
        dialogue.lines = {
            {text="you're doing really well!"},
            {text="sounds like we're not done with the high-jumpers yet though..."},
        }
    elseif lvl == 5 then
        dialogue.lines = {
            {text="nice!"},
            {text="yikes, i hear those little speedy guys!"},
        }
    elseif lvl == 6 then
        dialogue.lines = {
            {text="i'm impressed with how far you've come"},
            {text="it looks the next wave is the last of them all...", char_t=3},
            {text="i hope you're ready for the froggy gliders!"},
        }
    elseif lvl == 7 then
        dialogue.lines = {
            {text="wow, you really did it! you beat all the waves!"},
            {text="i'll miss you, little friend. thank you for protecting me.", char_t=3},
            {text="i guess this is where we say goodbye...", char_t=4},
            {text="...", char_t=6, end_t=120, rmb=2},
            {text="what was that?", rmb=0},
            {text="oh no, it looks like you've unlocked the final challenge:"},
            {text="\^w\^tendless mode", col=clr.yellow, char_t=4, end_t=120},
            {text="if you ever want to skip straight to endless mode in the future..."},
            {text="you can press all these buttons at once: ⬅️,➡️,z,❎", char_t=3, end_t=180, col=clr.blue},
            {text="good luck, i have faith in you!"},
        }
    elseif lvl == 999 then
        dialogue.lines = {
            {text="let endless mode commence!"}
        }
    else
        next_is_ending = true
    end
    dialogue.phrase_no = 1
    local line = dialogue.lines[dialogue.phrase_no]
    dialogue.phrase = make_phrase(line.text, line.col, line.end_t, line.char_t, line.rmb)
    local parent_update = dialogue.update
    dialogue.update = function(this)
        parent_update(this)
        this.phrase:update()
        if this.phrase.done then
            this.phrase_no += 1
            if this.phrase_no > #this.lines then
                this.done = true
                return
            end
            local line = dialogue.lines[dialogue.phrase_no]
            this.phrase = make_phrase(line.text, line.col, line.end_t, line.char_t, line.rmb)
        end
    end
    dialogue.draw = function(this)
        this.phrase:draw()
    end
    dialogue.next_state = function(this)
        if next_is_ending then
            return make_ending()
        elseif lvl < 1 then
            return make_wave(lvl)
        elseif (lvl == 7) or (lvl == 999) then
            return make_endless_transition()
        else
            return make_wave_transition(lvl)
        end
    end
    return dialogue
end

function make_endless_transition()
    return make_transition("\^w\^tendless mode", 80, clr.red)
end

function make_wave_transition(lvl)
    return make_transition("\^w\^twave "..lvl, 105, clr.yellow, lvl)
end

function make_transition(wave_str, x, col, lvl)
    local transition = make_game_state()
    transition.max_t = 120  -- Total duration of the transition
    transition.flash_speed = 4 -- Speed of color flashing
    music(-1)
    sfx(23)
    
    transition.update = function(this)
        if this.t >= this.max_t then
            this.done = true
        end
        this.t += 1
    end
    
    transition.draw = function(this)
        if this.t < this.max_t then
            -- Pick a color based on the flash effect
            local color = (flr(this.t / this.flash_speed) % 2 == 0) and clr.white or col
            local y = 60
            if this.t < 20 then
                rumble = 2
                y -= 20-this.t
            else
                rumble = 0
            end
            print(wave_str, x, y, color)
        end
    end
    
    transition.next_state = function(this)
        return lvl and make_wave(lvl) or make_endless_wave()
    end
    
    return transition
end

function spawn(enemy, flip, x, y)
    return function()
        make_enemy(enemy, flip, x, y)
    end
end

function deep_copy_table(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = deep_copy_table(v) -- recursively copy tables
        else
            copy[k] = v
        end
    end
    return copy
end

function get_default_interval(my_froglet)
    if my_froglet == charger then
        return 32
    elseif my_froglet == pink_froglet then
        return 26
    else
        return 60
    end
end

function wave_factory()
    local wf = {
        t = 0,
        wave = {},
        add = function(this, dt, action)
            this.t += dt
            add(this.wave, {this.t, action})
            return this
        end,
        spawn = function(this, dt, enemy, flip, x, y)
            return this:add(dt, spawn(enemy, flip, x, y))
        end,
        fswarm = function(this, dt, count, flip, my_froglet, interval)
            my_froglet = my_froglet or froglet
            interval = interval or get_default_interval(my_froglet)
            this:spawn(dt, my_froglet, flip)
            for i = 2,count do
                this:spawn(interval, my_froglet, flip)
            end
            return this
        end,
        get_wave_and_reset = function(this)
            local wave_copy = this.wave
            this.t = 0
            this.wave = {}
            return wave_copy
        end
    }
    return wf
end

function rs()
    return choose_random({true, false})
end

iwave = 5
function get_wave_actions(lvl)
    local wf = wave_factory()
    local s=rs()
    if lvl == -2 then
        return wf:spawn(0, froglet, false).wave
    elseif lvl == -1 then
        return wf:fswarm(0, 5, true):get_wave_and_reset()
    elseif lvl == 0 then
        return wf:spawn(0, toad, false):get_wave_and_reset()
    elseif lvl == 1 then
        wf:fswarm(0, 5, rs())
        wf:fswarm(-60, 5, rs())
        wf:spawn(60*3, toad, rs())
        for i=2,5 do
            wf:fswarm(60*3, i, rs())
            wf:fswarm(30, i, rs())
        end
        wf:spawn(60, toad, rs())
        return wf:get_wave_and_reset()
    elseif lvl == 2 then
        wf:spawn(0, pilot, true)
        wf:spawn(300, pilot, false)
        wf:fswarm(60, 5, rs())
        wf:spawn(400, pilot, true)
        wf:spawn(300, pilot, false)
        wf:fswarm(200, 5, rs())
        wf:spawn(60, pilot, true)
        wf:fswarm(200, 5, false)
        wf:spawn(40, pilot, true)
        wf:spawn(200, toad, false)
        wf:spawn(150, pilot, true)
        return wf:get_wave_and_reset()
    elseif lvl == 3 then
        wf:fswarm(0, 5, false, pink_froglet)
        wf:fswarm(-30, 5, true, pink_froglet)
        wf:spawn(60*3, toad, false)
        for i=2,5 do
            wf:fswarm(60*3, i, true, pink_froglet)
            wf:fswarm(30, i, false, pink_froglet)
            wf:fswarm(0, 5, choose_random({true, false}))
            if i == 4 or i == 5 then
                wf:spawn(-30, pilot, i==4)
            end
        end
        wf:spawn(120, toad, true)
        return wf:get_wave_and_reset()
    elseif lvl == 4 then
        wf:spawn(0, pink_toad, false)
        wf:fswarm(300, 5, false)
        wf:spawn(60, pilot,false)
        wf:spawn(120, pink_toad, true)

        wf:fswarm(300, 5, true, pink_froglet)
        wf:spawn(60, pilot, true)
        wf:spawn(120, pink_toad, false)
        wf:spawn(60, pilot, true)
        wf:spawn(120, pilot, false)

        wf:spawn(500, toad, true)
        wf:spawn(400, pink_toad, true)
        wf:fswarm(120, 5, true, pink_froglet)
        return wf:get_wave_and_reset()
    elseif lvl == 5 then
        wf:spawn(0, charger, rs())
        wf:spawn(60, charger, rs())
        wf:fswarm(100, 3, rs(), charger, 32)
        wf:fswarm(100, 3, rs(), charger, 32)
        wf:spawn(100, pilot, true)
        wf:fswarm(30, 3, rs(), charger)
        wf:spawn(60, pilot, false)
        wf:fswarm(30, 3, rs(), charger)

        s=rs()
        wf:fswarm(100, 8, s, choose_random({froglet, froglet, pink_froglet}))
        wf:fswarm(-60, 3, s, charger)
        s=rs()
        wf:spawn(120, pilot, rs())
        wf:fswarm(20, 8, s, choose_random({froglet, froglet, pink_froglet}))
        wf:fswarm(-60, 5, s, charger)
        wf:spawn(-60, pilot, rs())

        s=rs()
        wf:spawn(200, choose_random({toad, toad, pink_toad}), s)
        wf:spawn(60, pilot, true)
        wf:fswarm(60, 3, s, charger)
        wf:spawn(60, pilot, false)
        wf:fswarm(60, 3, not s, charger)
        wf:spawn(60, pilot, true)

        s=rs()
        wf:spawn(300, toad, s)
        wf:spawn(30, pilot, false)
        wf:spawn(200, pilot, true)
        wf:spawn(160, pink_toad, s)
        wf:spawn(30, pilot, false)
        wf:spawn(200, pilot, true)
        wf:fswarm(-100, 5, s, charger)
        wf:fswarm(120, 3, not s, charger)
        return wf:get_wave_and_reset()
    elseif lvl == 6 then
        wf:spawn(0, pink_pilot, true)
        wf:spawn(300, pink_pilot, false)
        s=rs()
        wf:spawn(300, pink_pilot, s)
        wf:spawn(300, pink_pilot, not s)
        wf:fswarm(60, 5, rs(), choose_random({froglet, froglet, pink_froglet}))
        wf:spawn(200, pink_pilot, true)
        wf:spawn(300, pink_pilot, false)
        wf:fswarm(60, 5, rs(), choose_random({froglet, froglet, pink_froglet}))
        wf:spawn(60, pink_pilot, true)
        wf:fswarm(200, 5, false)

        s=rs()
        wf:spawn(40, pink_pilot, true)
        wf:spawn(200, toad, s)
        wf:spawn(150, pink_pilot, true)

        wf:spawn(40, pink_pilot, false)
        wf:spawn(200, pink_toad, not s)
        wf:spawn(150, pink_pilot, false)

        wf:fswarm(300, 3, not s, charger)
        wf:fswarm(200, 3, s, charger)
        return wf:get_wave_and_reset()
    end
end

function make_wave(lvl)
    current_lvl = lvl
    music(1,0,3)
    local wave = make_game_state()
    wave.actions = get_wave_actions(lvl)
    wave.executed_actions = {}   
    wave.update = function(this)
        -- Check if all actions are executed and no enemies are left        
        if #enemies == 0 then
            local all_actions_executed = true
            for i = 1, #this.actions do
                if not this.executed_actions[i] then
                    all_actions_executed = false
                    break
                end
            end
            if all_actions_executed then
                this.done = true
                return
            end
        end
    
        -- Process wave actions
        for i, wave_action in ipairs(this.actions) do
            local action_time = wave_action[1]
            local action_func = wave_action[2]
    
            -- Trigger action if time has passed and it's not already executed
            if this.t >= action_time and not this.executed_actions[i] then
                action_func()
                this.executed_actions[i] = true
            end
        end
    
        -- Increment the timer for the wave
        this.t += 1
    end
        
    wave.next_state = function(this)
        return make_dialogue(lvl + 1)
    end
    
    return wave
end

function calc_dt(minimum, diff, rate)
    rate = rate or 9/10
    return minimum + (minimum*2)*(rate^diff)
end

function calc_enemy_difficulty(minimum, diff, rate)
    rate = rate or 9/10
    local is_easy = rnd(100) < minimum + (100 - minimum)*(rate^diff)
    return is_easy and 1 or 2
end

function calc_next_t(t, dt)
    return t + dt + rnd(dt)
end

function make_spawner(enemy, flip)
    local spawner = {
        t = 0,
        num_spawned = 0,
        max_spawned = (enemy == charger) and 3 or 5,
        interval = get_default_interval(enemy)*2,
        update = function(this)
            -- If max enemies are spawned, remove the spawner
            if this.num_spawned >= this.max_spawned then
                del(spawners, this)
            -- If enough time has passed, spawn an enemy
            elseif this.t == 0 then
                make_enemy(enemy, flip)
                this.num_spawned += 1
            end
            -- Increment the timer and reset it based on the interval
            this.t = (this.t + 1) % this.interval
            debug("spawner t: "..this.t)
        end
    }
    add(spawners, spawner)
    return spawner
end

function spawn_enemy(code, difficulty)
    local enemy_map = {{froglet, pink_froglet, charger}, {toad, pink_toad}, {pilot, pink_pilot}}
    local enemy = enemy_map[code][difficulty]
    if code == 1 then
        add(spawners, make_spawner(enemy, rs()))
    else
        make_enemy(enemy, rs())
    end
end

function make_endless_wave()
    local state = make_wave(999)
    state.min_dt = {100,200,60} -- swarm, toad, pilot
    state.min_easy_chance = {5,30,20}
    state.spawner = {update = function(this)end}
    state.dt = {}
    state.next_t = {10,60,30}
    state.update = function(this)
        if (this.t % 100) == 0 then
            this.diff = (1/30)*(sqrt(2*this.t+225)-15)
            for i = 1,3 do
                this.dt[i] = calc_dt(this.min_dt[i], this.diff)
            end
        end
        for i = 1,3 do
            if this.t >= this.next_t[i] then
                local difficulty = calc_enemy_difficulty(this.min_easy_chance[i], this.diff)
                if i == 1 then
                    difficulty += calc_enemy_difficulty(30, this.diff) - 1
                end
                spawn_enemy(i, difficulty)
                this.next_t[i] = calc_next_t(this.t, this.dt[i])
            end
        end
        for spawner in all(spawners) do
            spawner:update()
        end    
        this.t += 1
    end
    state.t = 0
    state:update()
    return state
end

function make_game(initial_state)
    local game = {
        state = initial_state,
        update = function(this)
            if this.state.done then
                this.state = this.state:next_state()
            end
            this.state:update()
        end,
        draw = function(this)
            this.state:draw()
        end
    }
    return game
end

function sqrd_d(dx, dy)
    return dx*dx+dy*dy
end

function update_position_history(entity)
    if #entity.history > 0 and sqrd_d(entity.history[1].x-entity.x, entity.history[1].y-entity.y) < 1 then
        return
    end
    add(entity.history, {x = entity.x, y = entity.y}, 1)
    
    -- Trim the history to maintain the desired length
    if #entity.history > position_history_length then
        del(entity.history, entity.history[#entity.history])
    end
end

function _update60()
    high_score = max(high_score, score)

    --skip
    if btn(🅾️) and btn(❎) and btn(⬅️) and btn(➡️) then
        restart_game(999)
    end

    --game
    game:update()

    --player
    update_player()

    --torches
    for torch in all(torches) do
        torch:update()
    end

    --salamancer
    salamancer:update()

    --enemies
    -- make_enemies()
    for enemy in all(enemies) do
        enemy:update()
    end

    --bullets
    for bullet in all(bullets) do
        bullet:update()
    end

    -- embers
    foreach(embers, move_ember)

    --flash bang
    if pl.dash_time <= 1 then
        flash_bang.x = pl.x
        flash_bang.y = pl.y
    end

    --camera
    set_camera(rumble)
end

function draw_player()
    local col, rim_col = pl.col, pl.rim_col

    -- Flash when charge is full
    if pl.charge_time >= ps.max_charge_time then
        if pl.charge_time % 2 == 0 then
            col = clr.white
        end
    end

    -- Flash when stunned
    if pl.stun_time >= 0 then
        if pl.stun_time % 4 < 2 then
            col = clr.black
        else
            col = clr.peach
        end
        rim_col = clr.white
    end

    circfill(pl.x, pl.y, pl.radius, col)
    circ(pl.x, pl.y, pl.radius, rim_col)
    if pl_is_charging() then
        charging_frame = flr(pl.charge_time / 5) % pl.radius
        circ(pl.x, pl.y, pl.radius - charging_frame, clr.white)
    
        -- Add lines coming in from the edge of the circle
        local rotation_speed = 0.15
        local rotation_frame = flr(pl.charge_time / 10) % pl.radius
        local rotated_angle = rotation_frame * rotation_speed    
        local line_count = 8 -- number of lines
        local radius = 10
        for i = 1, line_count do
            local angle = (i / line_count) + rotated_angle
            local outer_x = pl.x + cos(angle) * radius
            local outer_y = pl.y + sin(angle) * radius
            local inner_x = pl.x + cos(angle) * (radius - rotation_frame)
            local inner_y = pl.y + sin(angle) * (radius - rotation_frame)
            line(outer_x, outer_y, inner_x, inner_y, clr.white)
        end
    end
end

function draw_flash_bang()
    --we just dashed - explode!
    local dash_frame = pl.dash_time
    local x = flash_bang.x
    local y = flash_bang.y

    --light burst
    if pl.dash_end_time >= ps.max_dash_time-1 then
        local max_radius = 50
        local burst_radius = max_radius * (1 - (dash_frame/ps.max_dash_time))
        circfill(x, y, burst_radius, clr.yellow)    
    end

    --white rays
    local length = 50 - 50*((ps.max_dash_time - pl.dash_end_time)/ps.max_dash_time)
    for i=1,4 do
        -- local trig_arg = (i + dash_frame/10)/4
        local trig_arg = i/4
        line(x, y, x+length*cos(trig_arg), y+length*sin(trig_arg), clr.white)
    end
end

function draw_sal_health()
    local x, c = 64, salamancer.hurt_time >= 0 and clr.pink or clr.blue
    rectfill(x+30,120+2,x+128-30,120+6,clr.black)
    rectfill(x+31,120+3,x+32+(salamancer.life / salamancer.max_life)*65,120+5,c)
end

function is_on_screen(x, w)
    return x + w > cam_x and x < 128 + cam_x
end

function pxage_blue(page)
    local col=7
    if page>5 then
        col=13
    end
    if page>10 then
        col=2
    end
    if page>15 then
        col=5
    end
    return col
end  
function pxage_red(page)
    local col=7
    if page>5 then
        col=9
    end
    if page>8 then
        col=15
    end
    if page>11 then
        col=4
    end
    if page>14 then
        col=8
    end
    if page>19 then
        col=5
    end
    return col
end

function check_offscreen_enemies()
    local enemy_offscreen_left = false
    local enemy_offscreen_right = false

    -- Loop through all enemies
    for enemy in all(enemies) do
        if (enemy.x + enemy.sw[enemy.frame] < cam_x) and (enemy.damage > 0) then
            -- Enemy is offscreen to the left
            enemy_offscreen_left = true
        elseif (enemy.x > cam_x+128) and (enemy.damage > 0) then
            -- Enemy is offscreen to the right
            enemy_offscreen_right = true
        end
    end

    return enemy_offscreen_left, enemy_offscreen_right
end

function draw_offscreen_indicators()
    indicator_arrow_t += 1

    -- Check for offscreen enemies
    local left_indicator, right_indicator = check_offscreen_enemies()
    
    local sx, sy, sw, sh, dx, dy, flip
    sx = 102
    sy = 54
    sw = 16
    sh = 11
    dy = 59
    
    -- Create blinking effect using pal
    local blink_interval = 30
    local blink = (indicator_arrow_t % (2 * blink_interval)) < blink_interval
    
    -- Calculate oscillating x offset using sin
    local oscillation_speed = 0.05
    local x_offset = 2 * sin(indicator_arrow_t * oscillation_speed)
    
    if blink then
        pal(clr.red, clr.yellow)
    end

    -- Draw left indicator
    if left_indicator then
        dx = cam_x + 2 + x_offset
        sspr(sx, sy, sw, sh, dx, dy)
    end
    
    -- Draw right indicator
    if right_indicator then
        dx = cam_x + 128 - 2 - sw - x_offset
        flip = true
        sspr(sx, sy, sw, sh, dx, dy, sw, sh, flip)
    end
    reset_pal()
end

-- function draw_stats()
--     local cpu_usage = stat(1)
--     local mem_usage = stat(0)
--     local cpu_str = "cpu: "..tostr(cpu_usage)
--     local mem_str = "mem: "..tostr(mem_usage)
--     local rect_width = #cpu_str + #mem_str * 4 + 4 -- Each character is about 4 pixels wide
--     local x = cam_x
--     local y = 122
--     print(cpu_str, x + 2, y, 7) -- 7 is for white color
--     print(mem_str, x + 64, y, 7) -- 7 is for white color
-- end

function draw_scores(score, high_score)
    local y, margin, x = 0, 2, cam_x
    -- rectfill(x, bottom_y, x+128-40, 128, 0)
    print("score: "..score, x+margin, y + margin, 7) -- white text
    print("high: "..high_score, x+64, y + margin, 7) -- display high score on the right
end
   
function _draw()
    cls(clr.grey)

    --torch light
    for torch in all(torches) do
        local x,y,r
        x = torch.x+torch.sw/2
        y = torch.y+torch.sh/2-3
        r = 10+rnd(3)
        if is_on_screen(x-r, r*2) then
            circfill(x, y, r, clr.brown)
        end
    end

    --player light
    local light_x = pl.x - 2*pl.dx
    local light_y = pl.y - 2*pl.dy
    local light_color = salamancer.blink_color
    circfill(light_x - 2*pl.dx, light_y - 2*pl.dy, 57+rnd(5), clr.brown)
    circfill(light_x, light_y, 15, light_color)
    circ(light_x, light_y, 17, light_color)
    circ(light_x, light_y, 18, light_color)
    circ(light_x, light_y, 21, light_color)

    --salamancer light
    circfill(128, 128-8, 32+rnd(2), clr.blue)

    --room
    map(0,0)

    --torches
    for torch in all(torches) do
        if is_on_screen(torch.x, torch.sw) then
            torch:draw()
        end
    end

    --game (dialogue, wave transition)
    game:draw()

    --flash bang
    local dash_frame = pl.dash_time
    if dash_frame <= 3 and dash_frame >= 0 then
        draw_flash_bang()
    end

    --enemies
    for enemy in all(enemies) do
        if is_on_screen(enemy.x, enemy.sw[enemy.frame]) then
            enemy:draw()
        end
    end

    --salamancer
    salamancer:draw()

    --offscreen indicators
    draw_offscreen_indicators()

    --player
    draw_player()

    draw_sal_health()

    draw_scores(score, high_score)
        
    --drawing particles
    for mypx in all(parts) do
        local pc=7
        if mypx.blue then
            pc=pxage_blue(mypx.age)
            mypx.spark=false
        else
            pc=pxage_red(mypx.age)
        end
        
        if mypx.spark then
            pset(mypx.x,mypx.y,8)
        else
            circfill(mypx.x,mypx.y,mypx.size,pc)
        end
        mypx.x+=mypx.sx
        mypx.y+=mypx.sy
        mypx.sx*=0.95
        mypx.sy*=0.95
        mypx.age+=1
        if mypx.age>mypx.maxage then
            mypx.size-=0.5
            if mypx.size<0 then
                del(parts,mypx)
                mypx.age=0
            end
        end
    end

    --embers
    foreach(embers, draw_ember)

    --bullets
    for bullet in all(bullets) do
        bullet:draw()
    end

    -- draw_stats()
end
