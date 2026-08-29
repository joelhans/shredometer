// ============================================================
// Shredometer bottle-cage mount + cradle
// ============================================================
// Two parts in one file: (1) a "spine" baseplate that bolts to a
// standard 2-bolt water-bottle boss on the frame, and (2) two cradle
// rings, top and bottom, that hug the Shredometer's enclosure the way
// a bottle cage hugs a bottle -- long axis vertical, parallel to the
// mount.
//
// Assumptions baked into this first draft (all just variables below --
// flag any of these if they're wrong for your bike or enclosure):
//   - Standard 64mm bottle-boss spacing (M5 bolts), with a few mm of
//     vertical slot travel added as "wiggle room" for install.
//   - The enclosure's 44mm dimension sits front-to-back (against the
//     frame) and the 56mm dimension sits side-to-side. If it's more
//     comfortable the other way round, swap ENCL_DEPTH and ENCL_WIDTH.
//   - Front-to-back retention is a light inward pinch near the front
//     opening of each ring, which the ring flexes open slightly to
//     admit -- not a separate thin cantilever tab. This is the main
//     thing to validate with the cradle test prints: if it's too
//     stiff to open, reduce SNAP_BUMP or WALL; if it's too loose to
//     hold the enclosure, increase SNAP_BUMP. If it won't flex at all
//     in your filament, that's worth telling me -- a proper cantilever
//     latch is a reasonable next iteration.
//   - Vertical retention (stopping the enclosure sliding down and out
//     under vibration) is a solid floor in the bottom ring only. The
//     top ring is open top and bottom -- gravity isn't pulling the
//     enclosure out through the top, only the bottom.
//   - Top-ring corner clips were tried and dropped (see the note above
//     BRACE_DROP below): once the bottom ring's fit was dialed in and
//     the top ring got a brace down to the spine's bolted span, the
//     clips stopped being needed. Retention at the top is now just the
//     front-opening pinch, same as the bottom ring.
//   - Ring-to-spine joints use M3 cap-head screws into nuts pressed
//     into hex pockets on the spine's back face (see nut_pocket()) --
//     a clearance hole this size gives a self-tapping screw nothing to
//     bite into, so the nut carries the clamping load instead. The top
//     ring's brace has a window over the top M5 bolt's counterbore
//     (see brace_window()) so that bolt stays reachable once bolted on.
//
// Print small pieces first, in this order:
//   RENDER = "mount"        -> just the spine. Test it against your
//                              actual frame bosses before trusting
//                              BOLT_SPACING.
//   RENDER = "cradle"       -> the top-ring style (open top and
//                              bottom, includes the brace). Test the
//                              fit and the pinch around the real
//                              enclosure, or a scrap block cut to the
//                              same 56x44mm cross-section.
//   RENDER = "cradle_floor" -> the bottom-ring style (adds the
//                              perimeter floor lip). Test that the
//                              enclosure rests on the lip cleanly and
//                              still slides in past the pinch from
//                              the front.
//   RENDER = "full"         -> the whole cage, once the above look
//                              right.

// ---------------- Shredometer enclosure (measured) ----------------
ENCL_LEN   = 99;   // long axis -- mounts vertically, like a bottle
ENCL_DEPTH = 43;   // assumed front-to-back (against the frame)
ENCL_WIDTH = 55;   // assumed side-to-side

// ---------------- Fit ----------------
FIT_CLEARANCE = 0.6;  // per-side gap around the enclosure; dial this
                       // in with the "cradle" test piece

// ---------------- Cradle rings ----------------
WALL               = 6;   // ring wall thickness -- needs to be deep enough
                           // to hold the M3 cap-head counterbore below
                           // (see JOINT_COUNTERBORE_DEPTH) with solid
                           // material still behind it
RING_HEIGHT        = 14;  // ring height along the long (Z) axis
RING_MARGIN_TOP    = 8;   // gap from the enclosure's top end to the cage's top
RING_MARGIN_BOTTOM = 8;   // gap from the enclosure's bottom end to the cage's bottom
FRONT_GAP_FRAC     = 0.55; // fraction of the inner width left open at front
SNAP_BUMP          = 0.4;  // inward pinch at the front lip -- see note above
SNAP_BAND_Y        = 6;    // how deep (front to back) the pinch band reaches
SNAP_BAND_Z        = 6;    // how tall (along the ring) the pinch band is
FLOOR_THICK        = 3;    // height of the bottom ring's floor
FLOOR_LIP_WIDTH    = 4;    // the floor is a perimeter lip, not a solid disc --
                            // this is how far it reaches in from the cavity
                            // wall. The enclosure's flat bottom rests on the
                            // rim; the center stays open to save material and
                            // print time. Assumes a flat enclosure underside --
                            // widen this if yours has a foot or boss near the
                            // edge that needs more support.

// ---------------- Bottle-cage bolt pattern ----------------
BOLT_SPACING  = 64;  // standard 2-bolt spacing, center to center
BOLT_HOLE_DIA = 5.5; // M5 clearance
WIGGLE        = 4;   // extra slot length beyond the bolt hole (each slot)
SPINE_WIDTH   = 22;
SPINE_THICK   = 10;  // grown from 8mm so there's still solid backing
                      // behind the deeper counterbore below, for the
                      // taller button-head-plus-washer stack

// Real bottle-cage bolt hardware (measured): a button head plus washer,
// used as one stack.
M5_HEAD_WASHER_OD  = 10; // widest point of the head+washer stack
M5_HEAD_WASHER_LEN = 6;  // length of that stack, base of head to washer face

// Counterbore for the bolt head, on the front face (the same side the
// cradle rings attach to). Most bottle-cage bolts are socket- or
// button-head, not the tapered kind a true countersink suits, so this
// is a straight cylindrical recess, not a cone. Sized from the measured
// hardware above plus a little clearance so it drops in and seats flush
// without binding.
BOLT_HEAD_DIA_CLEARANCE = 0.5;
BOLT_HEAD_LEN_CLEARANCE = 0.3;
COUNTERBORE_DIA   = M5_HEAD_WASHER_OD + BOLT_HEAD_DIA_CLEARANCE;
COUNTERBORE_DEPTH = M5_HEAD_WASHER_LEN + BOLT_HEAD_LEN_CLEARANCE;

// ---------------- Ring-to-spine fasteners ----------------
// Printing the whole cage as one piece isn't practical: each ring
// would appear as a full-width shelf partway up the thin spine, with
// nothing supporting it from below -- a bigger unsupported overhang
// than the cap's roof was. So the spine and both rings print
// separately (as the test pieces already do) and get joined
// permanently afterward. These are through-holes for an M3 cap-head
// screw through each ring's back wall, through the spine, into a nut
// pressed into a pocket on the spine's back (frame-facing) face --
// see nut_pocket() below. A clearance hole this size gives a plastic
// self-tapping screw nothing to bite into, so a captive nut carries
// the actual clamping load instead.
JOINT_HOLE_DIA     = 3.2;  // M3 clearance
JOINT_HOLE_SPACING = 12;   // between the two fasteners per ring, centered on X=0

// The screw goes in from inside the ring's cavity, through the back
// wall, into the spine -- so the head sits on the cavity-facing side,
// right where the enclosure needs to go. Without a recess for it, the
// head pokes into the enclosure's fit. Cap-head (socket-head) screws
// have a flat-bottomed cylindrical head, not the tapered kind a true
// countersink suits, so this is a straight counterbore, matching how
// bolt_counterbore() handles the M5 bottle-cage bolts. Sized from the
// measured screw head below plus a little clearance.
CAP_HEAD_DIA = 5.5; // measured, across the screw head
CAP_HEAD_LEN = 4;   // measured, head length

JOINT_COUNTERBORE_DIA   = CAP_HEAD_DIA + BOLT_HEAD_DIA_CLEARANCE;
JOINT_COUNTERBORE_DEPTH = CAP_HEAD_LEN + BOLT_HEAD_LEN_CLEARANCE;

// A hex nut pressed into a pocket on the spine's back face, captive so
// it can't spin when the screw is tightened from the ring side.
NUT_ACROSS_FLATS    = 5.5; // measured, flat-to-flat
NUT_THICK           = 2.4; // measured
NUT_POCKET_CLEARANCE = 0.2; // oversize on the flats for a snug press fit
NUT_POCKET_DEPTH_CLEARANCE = 0.3; // extra depth so the nut seats fully

// The top ring sits right at the top of the cage, past the spine's
// upper bolt (see BOLT_SPACING) -- its own back wall, on its own,
// fastens to the unsupported tip of the spine beyond that bolt, which
// doesn't hold firmly. A brace (see BRACE_DROP, below in "derived")
// extends the top ring's back wall down below its own bottom edge so
// its fastener lands within the spine's bolted span instead, both
// anchoring it more rigidly and giving the joint a longer, stiffer
// connection to the ring. The bottom ring doesn't need this -- its
// floor lip already does most of the work holding the enclosure, and
// it sits close enough to the spine's lower bolt already.
//
// How far down is derived, not fixed: the top bolt's counterbore (see
// bolt_counterbore()) is a big, elongated recess, and the brace has to
// clear the bottom of it with real spine material to spare -- landing
// the M3 joint's own counterbore inside or right at the edge of that
// recess leaves almost no solid material between the two.
JOINT_COUNTERBORE_CLEARANCE = 3; // gap between the M3 joint counterbore's
                                   // edge and the M5 counterbore's edge
JOINT_HOLE_EDGE_MARGIN      = 4;  // keeps the fastener this far from the
                                   // brace's own free tip

// A window through the top ring's brace, over the top M5 bolt's
// counterbore, so that bolt stays reachable once the ring is on --
// see brace_window() and the note above BRACE_DROP.
WINDOW_CLEARANCE = 1; // extra diameter beyond COUNTERBORE_DIA, so minor
                        // print/assembly misalignment still leaves the
                        // bolt fully reachable

// ---------------- Fit-check reference hardware ----------------
// Stand-in M5 bottle-cage bolts, M3 ring-to-spine screws, and their
// nuts, sized and positioned to match the real fasteners and the
// recesses cut for them, so a "full" render shows whether anything
// actually collides (like the M3/counterbore overlap this caught).
// Translucent, like enclosure_reference() -- for F5 preview/screenshots
// only, excluded from render/export.
M5_BOLT_SHANK_DIA = 5;  // nominal M5 shank -- thinner than the 5.5mm
                          // clearance hole, so it visibly passes through
M5_BOLT_ENGAGE    = 15; // shank length shown past the spine's back
                          // face, standing in for the frame boss
M3_SCREW_ENGAGE   = 8;  // shank length shown past the counterbore,
                          // through the spine and into the nut

// ---------------- Which piece to render ----------------
// "full" | "mount" | "cradle" | "cradle_floor"
// "cradle" is the top-ring style (open top and bottom); "cradle_floor"
// is the bottom-ring style (perimeter floor lip, see FLOOR_THICK and
// FLOOR_LIP_WIDTH above).
RENDER = "full";

$fn = 48;

// ==================== derived ====================
inner_w  = ENCL_WIDTH + 2*FIT_CLEARANCE;
inner_d  = ENCL_DEPTH + 2*FIT_CLEARANCE;
outer_w  = inner_w + 2*WALL;
outer_d  = inner_d + 2*WALL;
cage_len = ENCL_LEN + RING_MARGIN_TOP + RING_MARGIN_BOTTOM;

// front-opening gap and the corner "posts" left on either side of it --
// used by cradle_ring() for the front insertion opening
gap      = inner_w * FRONT_GAP_FRAC;
finger_w = (outer_w - gap) / 2;

// how far a ring's local Y=0 (its own center) sits from the spine's
// front face, so the ring's back wall overlaps the spine cleanly
ring_y_offset = SPINE_THICK/2 + outer_d/2 - 0.5;

// ---- bottle-cage bolt and ring-to-spine joint Z positions ----
// shared by spine(), full_cage(), and the fit-check reference hardware
// below, so they can't drift out of sync with each other
bottom_bolt_z = cage_len/2 - BOLT_SPACING/2;
top_bolt_z    = cage_len/2 + BOLT_SPACING/2;

bottom_ring_joint_z = (RING_MARGIN_BOTTOM - FLOOR_THICK) + RING_HEIGHT/2;

// lowest Z the top bolt's counterbore recess reaches (it's a slot-shaped
// recess, elongated by WIGGLE, not just a plain round hole)
top_bolt_counterbore_z_min = top_bolt_z - WIGGLE/2 - COUNTERBORE_DIA/2;
top_ring_joint_z = top_bolt_counterbore_z_min
                     - JOINT_COUNTERBORE_CLEARANCE - JOINT_COUNTERBORE_DIA/2;

// absolute Z of the top ring's own bottom edge -- shared by full_cage(),
// the BRACE_DROP derivation below, and brace_window() (which needs to
// convert top_bolt_z into the ring's own local frame)
top_ring_bottom_z = cage_len - RING_MARGIN_TOP - RING_HEIGHT;

// how far below the top ring's own bottom edge the brace has to reach
// to land its fastener at top_ring_joint_z
BRACE_DROP = top_ring_bottom_z - top_ring_joint_z + JOINT_HOLE_EDGE_MARGIN;

// ==================== modules ====================

// Transparent stand-in for the real enclosure, for fit-checking in the
// F5 preview only -- the leading "%" excludes it from render/export.
module enclosure_reference() {
  %translate([-ENCL_WIDTH/2, ring_y_offset - ENCL_DEPTH/2, RING_MARGIN_BOTTOM])
    cube([ENCL_WIDTH, ENCL_DEPTH, ENCL_LEN]);
}

// Fake M5 bottle-cage bolts (head+washer seated in the counterbore,
// shank through the spine and on into where the frame boss would be),
// M3 ring-to-spine screws (cap head in the ring's cavity-facing wall,
// shank through the spine into a nut), and those nuts -- translucent,
// F5-preview-only fit check, same as enclosure_reference() above.
module fastener_reference() {
  for (z = [bottom_bolt_z, top_bolt_z]) {
    %translate([0, SPINE_THICK/2 - COUNTERBORE_DEPTH, z])
      rotate([-90, 0, 0])
        cylinder(h = COUNTERBORE_DEPTH, d = M5_HEAD_WASHER_OD);
    %translate([0, -SPINE_THICK/2 - M5_BOLT_ENGAGE, z])
      rotate([-90, 0, 0])
        cylinder(h = SPINE_THICK - COUNTERBORE_DEPTH + M5_BOLT_ENGAGE, d = M5_BOLT_SHANK_DIA);
  }
  for (z = [bottom_ring_joint_z, top_ring_joint_z])
    for (s = [-1, 1]) {
      %translate([s * JOINT_HOLE_SPACING/2, ring_y_offset - inner_d/2 - JOINT_COUNTERBORE_DEPTH, z])
        rotate([-90, 0, 0])
          cylinder(h = JOINT_COUNTERBORE_DEPTH, d = CAP_HEAD_DIA);
      %translate([s * JOINT_HOLE_SPACING/2, ring_y_offset - inner_d/2 - JOINT_COUNTERBORE_DEPTH - M3_SCREW_ENGAGE, z])
        rotate([-90, 0, 0])
          cylinder(h = M3_SCREW_ENGAGE + JOINT_COUNTERBORE_DEPTH, d = JOINT_HOLE_DIA);
      %translate([s * JOINT_HOLE_SPACING/2, -SPINE_THICK/2, z])
        rotate([-90, 0, 0])
          cylinder(h = NUT_THICK, d = NUT_ACROSS_FLATS/cos(30), $fn = 6);
    }
}

// One bolt slot: pierces the spine thickness (Y axis), elongated along
// Z by WIGGLE for install adjustment.
module bolt_slot() {
  hull() {
    translate([0, 0,  WIGGLE/2]) rotate([-90, 0, 0]) cylinder(h = SPINE_THICK + 2, d = BOLT_HOLE_DIA, center = true);
    translate([0, 0, -WIGGLE/2]) rotate([-90, 0, 0]) cylinder(h = SPINE_THICK + 2, d = BOLT_HOLE_DIA, center = true);
  }
}

// Counterbore recess for one slot, on the spine's front face (+Y,
// where the cradle rings attach), sized to the same elongation as the
// slot below it so the bolt head can sit recessed anywhere along the
// adjustable range.
module bolt_counterbore() {
  hull() {
    translate([0, SPINE_THICK/2 - COUNTERBORE_DEPTH,  WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = COUNTERBORE_DEPTH + 1, d = COUNTERBORE_DIA);
    translate([0, SPINE_THICK/2 - COUNTERBORE_DEPTH, -WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = COUNTERBORE_DEPTH + 1, d = COUNTERBORE_DIA);
  }
}

// Hex pocket for a captive M3 nut, cut into the spine's back (frame-
// facing) face -- the ring-to-spine screw threads into this instead of
// self-tapping into plastic. $fn=6 gives a hexagon circumscribed by the
// cylinder's diameter, so the diameter has to be the across-flats size
// divided by cos(30) to come out to the right across-flats width.
module nut_pocket() {
  pocket_dia = (NUT_ACROSS_FLATS + NUT_POCKET_CLEARANCE) / cos(30);
  pocket_depth = NUT_THICK + NUT_POCKET_DEPTH_CLEARANCE;
  translate([0, -SPINE_THICK/2 - 0.5, 0])
    rotate([-90, 0, 0])
      cylinder(h = pocket_depth + 0.5, d = pocket_dia, $fn = 6);
}

// The baseplate: bolts to the frame's water-bottle boss.
module spine() {
  difference() {
    translate([-SPINE_WIDTH/2, -SPINE_THICK/2, 0])
      cube([SPINE_WIDTH, SPINE_THICK, cage_len]);
    for (z = [bottom_bolt_z, top_bolt_z])
      translate([0, 0, z]) {
        bolt_slot();
        bolt_counterbore();
      }
    // ring-to-spine fastener holes, one pair per ring, each with a
    // captive nut pocket on the back (frame-facing) face
    for (z = [bottom_ring_joint_z, top_ring_joint_z])
      for (s = [-1, 1])
        translate([s * JOINT_HOLE_SPACING/2, 0, z]) {
          rotate([-90, 0, 0])
            cylinder(h = SPINE_THICK + 2, d = JOINT_HOLE_DIA, center = true);
          nut_pocket();
        }
  }
}

// Window through the top ring's brace, directly over the top M5 bolt's
// counterbore, so that bolt stays reachable (hex key or screwdriver)
// once this ring is bolted on. Matches the counterbore's own elongated
// slot shape, oversized by WINDOW_CLEARANCE. Only called for the top
// ring -- the bottom ring's brace_drop is 0, so it never reaches down
// to where the bottom bolt is, and doesn't need this.
module brace_window() {
  window_z = top_bolt_z - top_ring_bottom_z; // top_bolt_z, converted into
                                               // the ring's own local frame
  window_dia = COUNTERBORE_DIA + WINDOW_CLEARANCE;
  hull() {
    translate([0, -outer_d/2 - 1, window_z + WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = WALL + 2, d = window_dia);
    translate([0, -outer_d/2 - 1, window_z - WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = WALL + 2, d = window_dia);
  }
}

// One cradle ring: an open-fronted "C" channel that hugs the
// enclosure's cross-section, with a light inward pinch near the front
// opening for retention. Sits with its own bottom at local Z=0,
// centered on X=0/Y=0.
//
// floor=true closes off the bottom with a perimeter lip (FLOOR_THICK
// tall, FLOOR_LIP_WIDTH wide) instead of leaving it open, so the
// enclosure rests on the lip rather than being free to slide straight
// down and out under vibration. The lip's center is hollow, to save
// material and print time -- it doesn't need to be a solid disc to
// hold a flat-bottomed enclosure up. It doesn't block the front
// opening above it, so it doesn't change how the enclosure is
// inserted. Use this on the bottom ring only -- the top ring stays
// fully open top and bottom.
//
// brace_drop > 0 extends the back wall down below the ring's own
// bottom edge (local Z=0), into negative Z, so its fastener lands
// within the spine's bolted span instead of out past it -- see the
// note above BRACE_DROP. Only the top ring uses this.
module cradle_ring(floor = false, brace_drop = 0) {
  floor_h = floor ? FLOOR_THICK : 0;
  brace_w = JOINT_HOLE_SPACING + JOINT_COUNTERBORE_DIA + 4;
  // where the fastener holes sit: through the brace, near its free
  // tip, if there is one -- otherwise centered on the ring's own wall
  joint_z = brace_drop > 0 ? -brace_drop + JOINT_HOLE_EDGE_MARGIN : RING_HEIGHT/2;

  difference() {
    union() {
      translate([-outer_w/2, -outer_d/2, 0])
        cube([outer_w, outer_d, RING_HEIGHT]);
      if (brace_drop > 0)
        translate([-brace_w/2, -outer_d/2, -brace_drop])
          cube([brace_w, WALL, brace_drop]);
    }
    translate([-inner_w/2, -inner_d/2, floor_h])
      cube([inner_w, inner_d, RING_HEIGHT + 1 - floor_h]);
    // front opening: cut the middle out of the +Y wall, leaving two
    // corner posts. Starts above the floor, if there is one.
    translate([-gap/2, inner_d/2 - 1, floor_h])
      cube([gap, WALL + 2, RING_HEIGHT + 1 - floor_h]);
    // hollow out the floor's center, leaving only the perimeter lip
    if (floor) {
      lip_w = inner_w - 2*FLOOR_LIP_WIDTH;
      lip_d = inner_d - 2*FLOOR_LIP_WIDTH;
      translate([-lip_w/2, -lip_d/2, -1])
        cube([lip_w, lip_d, floor_h + 1]);
    }
    // fastener holes through the back wall (or the brace, if there is
    // one), joining this (separately printed) ring to the spine --
    // must match spine()'s hole Z. Each gets a counterbore on the
    // cavity-facing side for the screw's cap head: the screw goes in
    // from inside the ring, so its head would otherwise sit proud into
    // the enclosure's fit.
    for (s = [-1, 1]) {
      translate([s * JOINT_HOLE_SPACING/2, 0, joint_z])
        rotate([-90, 0, 0])
          cylinder(h = outer_d + 2, d = JOINT_HOLE_DIA, center = true);
      translate([s * JOINT_HOLE_SPACING/2, -inner_d/2 - JOINT_COUNTERBORE_DEPTH, joint_z])
        rotate([-90, 0, 0])
          cylinder(h = JOINT_COUNTERBORE_DEPTH, d = JOINT_COUNTERBORE_DIA);
    }
    if (brace_drop > 0) brace_window();
  }
  // retention pinch, both sides, near the front opening
  for (side = [-1, 1])
    translate([
      side > 0 ? inner_w/2 - SNAP_BUMP : -inner_w/2,
      inner_d/2 - SNAP_BAND_Y,
      RING_HEIGHT/2 - SNAP_BAND_Z/2
    ])
      cube([SNAP_BUMP, SNAP_BAND_Y, SNAP_BAND_Z]);
}

// The whole cage: spine + two cradle rings. The bottom ring gets a
// floor; the top ring doesn't need one -- gravity isn't pulling the
// enclosure out through the top.
module full_cage() {
  union() {
    spine();
    // shifted down by FLOOR_THICK so the cavity above the floor still
    // starts exactly at RING_MARGIN_BOTTOM, where the enclosure sits
    translate([0, ring_y_offset, RING_MARGIN_BOTTOM - FLOOR_THICK])
      cradle_ring(floor = true);
    translate([0, ring_y_offset, top_ring_bottom_z])
      cradle_ring(floor = false, brace_drop = BRACE_DROP);
  }
}

// ==================== render dispatch ====================
if (RENDER == "full") {
  full_cage();
  enclosure_reference();
  fastener_reference();
} else if (RENDER == "mount") {
  // Standing up, this is 22x8mm at the base and cage_len (115mm) tall --
  // a tall, thin part that's prone to toppling and poor bed adhesion.
  // Lay it on its long face instead: low, wide, and stable. The bolt
  // holes print as clean vertical bores this way instead of horizontal
  // ones, so it's a win either way, not just a printability compromise.
  translate([0, 0, SPINE_THICK/2])
    rotate([90, 0, 0])
      spine();
} else if (RENDER == "cradle" || RENDER == "cradle_floor") {
  has_floor = (RENDER == "cradle_floor");
  floor_h = has_floor ? FLOOR_THICK : 0;
  brace_drop = has_floor ? 0 : BRACE_DROP;
  if (brace_drop > 0) {
    // The brace makes the ring's own bottom (local Z=0) just a thin
    // fin, not a real base. Printed upright on that fin, the full ring
    // footprint sits on top of a base a fraction as wide -- a big
    // unsupported overhang that fails without support material. The
    // back wall and brace are one continuous flat plane (see the note
    // above BRACE_DROP) -- lay that flat on the bed instead.
    rotate([90, 0, 0])
      translate([0, outer_d/2, 0])
        cradle_ring(floor = has_floor, brace_drop = brace_drop);
  } else {
    // lifted by brace_drop so the brace's own free tip (its lowest
    // point, on the top ring) sits on the bed at Z=0, not below it
    translate([0, 0, brace_drop])
      cradle_ring(floor = has_floor, brace_drop = brace_drop);
  }
  // reference box rests on top of the floor, not overlapping it -- shown
  // in the ring's own upright frame regardless of print orientation above
  translate([-ENCL_WIDTH/2, -ENCL_DEPTH/2, brace_drop + floor_h + (RING_HEIGHT - floor_h)/2])
    %cube([ENCL_WIDTH, ENCL_DEPTH, RING_HEIGHT - floor_h]);
} else {
  echo(str("Unknown RENDER value: ", RENDER, " -- use \"full\", \"mount\", \"cradle\", or \"cradle_floor\""));
}
