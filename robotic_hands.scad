// Open Hands: 3D-printable, tendon-driven robotic hands
//
// Each hand prints as separate parts that are pinned together:
//   - palm    (prints flat on its back; has knuckle forks and a thumb mount)
//   - links   (14 finger/thumb segments, each printed flat on its back)
//   - wrist   (prints upside down; the palm screws onto it)
// Hinges are fork-and-tongue joints held by 3 mm pins (steel rod, cut M3 screws or
// 3 mm filament). Each finger has two string channels: a palm-side flexor tendon
// that curls the finger, and a back-side channel for an elastic return cord.
// The parts are designed to print without supports.
//
// Choose what to render with `part` (also settable from the command line,
// e.g. openscad -D 'part="palm"' -D 'hand="right"' -o palm_right.stl robotic_hands.scad).

part = "assembly";   // "assembly" | "plate" | "palm" | "links" | "wrist"
hand = "right";      // "right" | "left" (palm and plate only; links and wrist fit both)

$fn = 48;

// ---------------- Print-fit parameters ----------------
c       = 1.0;    // radial clearance between a tongue and its fork crotch
sc      = 0.4;    // side clearance between a tongue and its fork prongs
pin_d   = 3.2;    // pin hole through the fork prongs (snug on a 3 mm pin)
pin_free_d = 3.5; // pin hole through the tongue (rotates freely)
chan_d  = 2.2;    // tendon / elastic channel diameter
chan_in = 3;      // channel inset from the palm/back faces of a link
screw_d = 2.8;    // M3 self-tapping pilot hole (palm-to-wrist and wrist mounting)
pad_h   = 1.6;    // grip pads protrude by half of this

// ---------------- Hand geometry ----------------
palm_w = 80;
palm_h = 85;
palm_t = 24;

// [x, knuckle raise, base width, thickness, [pin-to-pin lengths; last = tip length]]
fingers = [
    [-30, 5, 16,   16, [38, 26, 24]],   // index
    [-10, 9, 16,   16, [42, 28, 26]],   // middle
    [ 10, 7, 15.5, 16, [40, 27, 25]],   // ring
    [ 29, 0, 13.5, 14, [32, 23, 21]],   // pinky
];
wtaper       = [1, 0.93, 0.86];  // link width multiplier per segment
tongue_ratio = 0.42;             // tongue width as a fraction of link width
finger_exit  = 0.3;              // channels converge to x * this at the palm base

thumb_w   = 17;
thumb_t   = 17;
thumb_len = [34, 28];
thumb_ang = 48;                  // splay of the thumb away from the fingers (deg)
thumb_mount_len = 28;            // root of the thumb mount to its hinge pin
thumb_root = [-palm_w/2 + 6, palm_t/2 - thumb_t/2, 22];
thumb_exit_x = -14;

screw_pos = [[-18, -7], [18, -7]]; // palm-to-wrist screws (x, y)

// ---------------- Colors (assembly view only) ----------------
c_shell = [0.22, 0.24, 0.28];
c_link  = [0.80, 0.82, 0.86];
c_joint = [0.95, 0.55, 0.10];
c_pad   = [0.12, 0.12, 0.12];

// ---------------- Helpers ----------------
function lw(w, i) = w * wtaper[i];
function tw(w, i) = lw(w, i) * tongue_ratio;
function fy(t) = palm_t/2 - t/2;                        // backs of the fingers sit flush with the palm back
function pin_z(f) = palm_h + f[3]/2 + c + f[1];
thumb_dir = [-sin(thumb_ang), 0, cos(thumb_ang)];

module rrect(size, r) offset(r) square([size[0] - 2*r, size[1] - 2*r], center = true);
// Extrude a 2D profile (u = Y, v = Z) along X
module along_x(width) rotate([90, 0, 90]) linear_extrude(width, center = true) children();
// Extrude a 2D profile (u = X, v = Z) along Y
module along_y(width) rotate([90, 0, 0]) linear_extrude(width, center = true) children();
module capsule(a, b, d = chan_d) hull() { translate(a) sphere(d = d, $fn = 12); translate(b) sphere(d = d, $fn = 12); }
module pin_hole(len, d) rotate([0, 90, 0]) cylinder(d = d, h = len, center = true, $fn = 24);

// Two fork prongs around a hinge pin at z = zp. The back (+Y) is square so it prints flat
// and acts as a hyperextension stop. The palm side (-Y) is round so the joint can curl.
module fork(zp, w, t, tw_next) {
    R  = t/2;
    pw = (w - tw_next - 2*sc) / 2;
    for (s = [-1, 1])
        translate([s * (w/2 - pw/2), 0, 0])
            along_x(pw) hull() {
                translate([0, zp]) circle(R);
                translate([-R, zp - (R + c) - 1]) square([2*R, R + c + 1]);
                translate([0, zp]) square([R, R]);
            }
}

// ---------------- Finger link ----------------
// Proximal pin at the origin; distal pin (or fingertip end) at z = L; finger axis = +Z;
// palm side = -Y; back = +Y.
module link(L, w, t, tw_self, tw_next, tip) {
    R  = t/2;
    z0 = R + c;
    za = L - min(7, (L - z0) / 2);        // tendon anchor height (fingertip only)
    difference() {
        union() {
            color(c_link) {
                // tongue (rides in the previous fork)
                along_x(tw_self) hull() {
                    circle(R);
                    translate([-R, 0]) square([2*R, z0 + 1]);
                }
                if (tip) {
                    intersection() {
                        translate([0, 0, z0]) linear_extrude(L - z0) rrect([w, t], 2);
                        along_y(t + 2) hull() {
                            translate([-w/2, z0]) square([w, 1]);
                            translate([0, L - w/2]) circle(w/2);
                        }
                        along_x(w + 2) hull() {
                            translate([-R, z0]) square([2*R, 1]);
                            translate([0, L - R]) circle(R);
                            translate([0, z0]) square([R, L - z0]);
                        }
                    }
                } else {
                    translate([0, 0, z0]) linear_extrude(L - 2*z0) rrect([w, t], 2);
                    fork(L, w, t, tw_next);
                }
            }
            // grip pad on the palm side
            pad_end = tip ? L - R : L - z0;
            color(c_pad)
                translate([0, -R, (z0 + pad_end) / 2])
                    cube([w * 0.6, pad_h, (pad_end - z0) * 0.7], center = true);
        }
        pin_hole(w + 2, pin_free_d);
        if (!tip) translate([0, 0, L]) pin_hole(w + 2, pin_d);
        for (s = [-1, 1]) {
            y = s * (R - chan_in);
            capsule([0, y, -R - 1], [0, y, tip ? za : L + R + 1]);
        }
        if (tip) translate([0, 0, za]) rotate([90, 0, 0]) cylinder(d = chan_d, h = t + 4, center = true, $fn = 12);
    }
}

// ---------------- Palm ----------------
module knuckle(f) {
    w = f[2]; t = f[3]; R = t/2; zp = pin_z(f);
    translate([f[0], fy(t), 0]) {
        translate([-w/2, -R, palm_h - 6]) cube([w, 2*R, zp - (R + c) - (palm_h - 6)]);
        fork(zp, w, t, tw(w, 0));
    }
}

module thumb_mount() {
    R = thumb_t/2;
    translate(thumb_root) rotate([0, -thumb_ang, 0]) {
        translate([0, 0, -12]) linear_extrude(thumb_mount_len - (R + c) + 12) rrect([thumb_w, thumb_t], 2);
        fork(thumb_mount_len, thumb_w, thumb_t, tw(thumb_w, 0));
    }
}

module palm() {
    difference() {
        union() {
            color(c_shell) {
                along_y(palm_t) translate([0, palm_h/2]) rrect([palm_w, palm_h], 6);
                for (f = fingers) knuckle(f);
                thumb_mount();
            }
            color(c_pad)
                translate([-3, -palm_t/2, palm_h * 0.42])
                    cube([palm_w * 0.62, pad_h, palm_h * 0.55], center = true);
        }
        // knuckle pins and finger tendon channels
        for (f = fingers) {
            R = f[3]/2; y0 = fy(f[3]); zp = pin_z(f);
            translate([f[0], y0, zp]) pin_hole(f[2] + 2, pin_d);
            for (s = [-1, 1]) {
                y = y0 + s * (R - chan_in);
                capsule([f[0], y, zp + R + 2], [f[0], y, palm_h - 5]);
                capsule([f[0], y, palm_h - 5], [f[0] * finger_exit, y, -2]);
            }
        }
        // thumb pin and tendon channels
        R = thumb_t/2;
        translate(thumb_root) rotate([0, -thumb_ang, 0])
            translate([0, 0, thumb_mount_len]) pin_hole(thumb_w + 2, pin_d);
        s_bend = (thumb_root[0] - thumb_exit_x) / sin(thumb_ang);
        for (s = [-1, 1]) {
            y = thumb_root[1] + s * (R - chan_in);
            a = [thumb_root[0], y, thumb_root[2]] + (thumb_mount_len + R + 2) * thumb_dir;
            b = [thumb_root[0], y, thumb_root[2]] + s_bend * thumb_dir;
            capsule(a, b);
            capsule(b, [thumb_exit_x, y, -2]);
        }
        // pilot holes for the wrist screws
        for (p = screw_pos) translate([p[0], p[1], -1]) cylinder(d = screw_d, h = 15, $fn = 24);
    }
}

// ---------------- Wrist ----------------
// Top face at z = 0 (meets the palm). A 4 mm top plate carries the screws; tendons
// pass through its slot into the hollow tube. Screw M3 x 12 from inside the tube.
module wrist() {
    color(c_shell) difference() {
        union() {
            translate([0, 0, -40]) cylinder(h = 40, r = 26);
            translate([0, 0, -40]) cylinder(h = 8, r1 = 34, r2 = 26);
            translate([0, 0, -44]) cylinder(h = 4, r = 34);
        }
        translate([0, 0, -45]) cylinder(h = 41, r = 22);
        translate([0, 3.5, -5]) linear_extrude(6) rrect([32, 15], 3);   // symmetric: fits either hand
        for (p = screw_pos) translate([p[0], p[1], -5]) cylinder(d = 3.4, h = 6, $fn = 24);
        // blind pilot holes for mounting the wrist to an arm or base
        for (a = [45 : 90 : 360]) rotate([0, 0, a]) translate([29.5, 0, -45]) cylinder(d = screw_d, h = 8, $fn = 24);
    }
    if (part == "assembly") color(c_joint) translate([0, 0, -24]) difference() {
        cylinder(h = 5, r = 26.6);
        translate([0, 0, -1]) cylinder(h = 7, r = 25);
    }
}

// ---------------- Assembly ----------------
module pin_vis(w) color(c_joint) pin_hole(w + 1.2, 3);

module chain(w, t, lengths, curls, i = 0) {
    if (i < len(lengths)) {
        n = len(lengths);
        rotate([curls[i], 0, 0]) {
            link(lengths[i], lw(w, i), t, tw(w, i), i < n - 1 ? tw(w, i + 1) : 0, i == n - 1);
            translate([0, 0, lengths[i]]) chain(w, t, lengths, curls, i + 1);
        }
        pin_vis(i == 0 ? w : lw(w, i - 1));
    }
}

module hand_assembly(curls, thumb_curls) {
    wrist();
    palm();
    for (i = [0 : len(fingers) - 1]) {
        f = fingers[i];
        translate([f[0], fy(f[3]), pin_z(f)]) chain(f[2], f[3], f[4], curls[i]);
    }
    translate(thumb_root) rotate([0, -thumb_ang, 0]) translate([0, 0, thumb_mount_len])
        chain(thumb_w, thumb_t, thumb_len, thumb_curls);
}

// ---------------- Print layouts (flat side on the bed at z = 0) ----------------
module palm_print()  translate([0, 0, palm_t/2]) rotate([-90, 0, 0]) palm();
module wrist_print() rotate([180, 0, 0]) wrist();

module links_print() {
    sets = concat([for (f = fingers) [f[2], f[3], f[4]]], [[thumb_w, thumb_t, thumb_len]]);
    row_y = [0, 62, 112];
    for (k = [0 : len(sets) - 1], i = [0 : len(sets[k][2]) - 1]) {
        w = sets[k][0]; t = sets[k][1]; L = sets[k][2]; n = len(L);
        translate([k * 24, row_y[i] + t/2, t/2]) rotate([-90, 0, 0])
            link(L[i], lw(w, i), t, tw(w, i), i < n - 1 ? tw(w, i + 1) : 0, i == n - 1);
    }
}

module handed() { if (hand == "left") children(); else mirror([1, 0, 0]) children(); }

// Pin list for the build (printed to the console)
echo(str("Pins per hand: 14 x 3 mm. Lengths (mm): fingers ",
         [for (f = fingers) [for (i = [0 : 2]) round(i == 0 ? f[2] : lw(f[2], i - 1))]],
         ", thumb ", [thumb_w, round(lw(thumb_w, 0))]));

// ---------------- Output ----------------
open_pose = [[ 5,  5,  5], [ 3,  3,  3], [ 5,  5,  5], [ 8,  6,  6]];
grip_pose = [[50, 55, 40], [45, 60, 45], [55, 60, 45], [60, 65, 45]];

if (part == "assembly") {
    // Left hand (thumb on -X when the palm faces -Y): open
    translate([-85, 0, 0]) hand_assembly(open_pose, [5, 10]);
    // Right hand (mirror image): closing into a grip
    translate([85, 0, 0]) mirror([1, 0, 0]) hand_assembly(grip_pose, [70, 45]);
} else if (part == "palm") {
    handed() palm_print();
} else if (part == "links") {
    links_print();
} else if (part == "wrist") {
    wrist_print();
} else if (part == "plate") {
    handed() palm_print();
    translate([hand == "left" ? -178 : 80, 0, 0]) links_print();
}
