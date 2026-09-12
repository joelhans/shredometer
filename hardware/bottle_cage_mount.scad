// ============================================================
// Shredometer bottle-cage mount + cradle
// ============================================================
// Four printed parts:
//
//   spine         -- baseplate, bolts to the frame's 2-bolt water-
//                    bottle boss.
//   bottom cradle -- a closed collar with a solid floor. The
//                    enclosure stands on a foam pad here.
//   top cradle    -- a closed collar, open at the top.
//   lid           -- a flat plate that bolts onto the top cradle.
//                    This is the "roof": with a foam pad under it,
//                    it traps the enclosure vertically.
//
// The SD card sits on the enclosure's bottom face and has to come out
// after every ride, so the bottom collar's floor opens under the card
// slot. See "SD card access" below. Nothing has to be unbolted to read
// the card, which is also why the lid's screws thread into captive
// nuts rather than into the plastic.
//
// ---------------- What changed after the first ride ----------------
// The first version held the enclosure with friction alone: each
// collar was a "C" with an open front and a small inward pinch, and
// the top collar was open at both ends. On a real ride the enclosure
// worked its way up and out. Three changes fix that:
//
//   1. Both collars are now closed rings. No front opening, no pinch
//      bump, no window through either wall. A closed ring is far
//      stiffer than a "C" and it cannot spread open over a bump.
//   2. The top collar gets a bolt-on lid. The enclosure is now
//      captured between two foam pads (floor and lid) with a fixed
//      amount of crush, so it has nowhere to travel vertically.
//   3. Foam pads take up every remaining gap. See "Foam" below.
//
// A closed 6mm-wall ring cannot be flexed open to admit the
// enclosure, so the enclosure no longer goes in from the front. It
// drops straight down through the top collar into the bottom one,
// and the lid goes on last. Both collars share the same cavity, on
// the same axis, so this is one straight slide.
//
// ---------------- Foam ----------------
// 5mm firm closed-cell sheet, no adhesive backing, so every pad
// needs geometry to hold it in place:
//
//   floor pad -- lies on the bottom collar's solid floor. The cavity
//                walls box it in on all four sides.
//   lid pad   -- sits in a shallow pocket in the lid's underside.
//   back pads -- one per collar, in a shallow pocket milled into the
//                back wall (the spine side). Each pocket is closed at
//                the bottom, so insertion drag pushes the pad down
//                onto a ledge instead of dragging it out.
//
// Cut every pad about 1mm oversize in width and height and press it
// in. The pocket depth means only part of each pad's thickness
// stands proud, which keeps the cradle close to its old size.
//
// Foam only has to sit on one face of an axis to stop a rattle: it
// presses the enclosure against the opposite hard wall, and a
// preloaded contact does not buzz. So the back pads alone handle
// front-to-back. Side to side stays a plain sliding clearance.
//
// ---------------- Assembly order ----------------
// The ring-to-spine screws go in from inside, so they must be driven
// before the enclosure goes in. Both collars now hang off a brace
// that puts its screws in open air between the collars, clear of the
// closed walls, so a driver still reaches them.
//
//   1. Press an M3 nut into each of the four pockets on the spine's
//      back face, and one into each of the top collar's four corner
//      slots.
//   2. Bolt both collars to the spine (M3 cap screws, from inside).
//   3. Bolt the spine to the frame. Both M5 bolts sit between the
//      collars; each brace has a window over its own bolt.
//   4. Press the foam pads in: floor, both back pads, lid.
//   5. Slide the enclosure down through the top collar until it
//      rests on the floor pad.
//   6. Bolt the lid on, into the four corner nuts.
//
// Hardware: 8x M3x10 socket-head cap screws, 8x M3 nuts, plus the two
// M5 bottle-cage bolts. Every screw is the same length on purpose.
//
// ---------------- Print order ----------------
//   RENDER = "mount"         -> the spine, laid on its long face.
//   RENDER = "cradle_bottom" -> the bottom collar, upright.
//   RENDER = "cradle_top"    -> the top collar, upside down.
//   RENDER = "lid"           -> the lid, upside down.
//   RENDER = "full"          -> the whole cage, for preview only.
//
// Print one collar first and check that the enclosure slides through
// it with the back pad in. That is the only fit left to dial in, and
// FIT_CLEARANCE is the knob.

// ---------------- Shredometer enclosure (measured) ----------------
ENCL_LEN   = 99;   // long axis -- mounts vertically, like a bottle
ENCL_DEPTH = 43;   // front-to-back (against the frame)
ENCL_WIDTH = 55;   // side-to-side

// ---------------- Fit ----------------
// Side-to-side only. Front-to-back is set by the back foam pad, and
// vertical by the floor and lid pads, so neither uses this.
// The enclosure now slides the full length of the top collar, so
// this is a sliding clearance, not a press fit -- if it binds,
// raise it; if it rocks side to side, lower it.
FIT_CLEARANCE = 0.6;

// ---------------- Foam ----------------
FOAM_THICK          = 5;   // free thickness of the sheet
FOAM_V_CRUSH        = 0.8; // designed squash per pad, floor and lid.
                            // The lid bottoms out on the collar's top
                            // face, so this is a hard stop: it cannot
                            // be over-tightened, and it does not drift.
FOAM_BACK_CRUSH     = 0.8; // designed squash of each back pad
FOAM_POCKET_DEPTH   = 2;   // how far the back and lid pads sink into
                            // their pockets, so less of the pad stands
                            // proud and the cradle stays compact
FOAM_PAD_SIDE_MARGIN = 4;  // wall left on each side of a back pocket
BACK_PAD_LEDGE      = 1.5; // un-pocketed strip at the bottom of the
                            // top collar's back wall. The pad rests on
                            // it, so sliding the enclosure in cannot
                            // push the pad out the bottom. It sits
                            // flush with the cavity wall, so it never
                            // touches the enclosure.

// ---------------- Cradle collars ----------------
WALL         = 6;   // collar wall thickness -- deep enough to hold the
                     // M3 cap-head counterbore below (see
                     // JOINT_COUNTERBORE_DEPTH) with material behind it
RING_HEIGHT  = 14;  // cavity height of each collar, along the long (Z)
                     // axis. Both collars use the same value.
                     //
                     // Do not raise this much: the two M5 bolt heads
                     // have to stay reachable in the open span between
                     // the collars, and that span is what is left of
                     // the enclosure's length after both collars take
                     // their share. bolt_clearance below echoes how
                     // much room is left -- keep it positive.
RING_MARGIN_BOTTOM = 8; // gap from the cage's bottom to the cavity floor
FLOOR_THICK  = 3;   // solid floor under the bottom collar's cavity.
                     // Solid, not a perimeter lip: the floor foam pad
                     // needs backing across its whole area, or it
                     // dishes into the opening and the clamp goes soft.
DRAIN_DIA    = 5;   // drain holes through that floor -- the collar is
                     // closed all round now, so water needs a way out
ENTRY_CHAMFER = 2;  // lead-in flare at the top of each cavity, so the
                     // enclosure starts square instead of catching on
                     // an edge or peeling a back pad

// ---------------- Lid ----------------
LID_THICK       = 4;   // it seats on the collar's whole top rim, so it
                        // is a fully supported plate, not a beam
CORNER_BOSS     = 3;   // extra material added at the top collar's four
                        // corners. Sized to swallow a captive M3 nut with
                        // a wall either side, not just to clear the screw.
BOSS_SIZE       = 9;   // square corner boss, measured from its outer
                        // corner. Its inner faces land flush with the
                        // cavity walls.
LID_SCREW_INSET = 4;   // lid screw centre, in from the boss's outer
                        // corner on both axes. Sits slightly outboard of
                        // the boss's middle on purpose: that thickens the
                        // wall between the nut slot's inner end and the
                        // cavity, and the slot's outer end is open anyway.

// The lid's four screws thread into captive M3 nuts, the same as the
// collar-to-spine joints, rather than self-tapping into the plastic.
// The lid comes off every time the enclosure does, and threads cut
// into PLA wear out after a few tens of cycles. A nut does not.
// Each nut slides into a slot in its corner boss from the outside.
LID_NUT_DEPTH   = 3;   // solid boss between the lid's underside and the
                        // top of the nut slot. This is the material the
                        // screw actually clamps, so it carries the whole
                        // foam preload.
LID_NUT_SLOT_CLEARANCE = 0.2; // on the nut's flats, for a press fit --
                                // same figure as the spine's nut pockets

// Cutout through the lid, over the controls on the enclosure's top
// face: an on-off switch plus reset and start buttons, as one block.
// Measured on the enclosure itself, from the middle of its top face:
// +Y is forward, away from the frame. The block is centred side to
// side, so its X is 0 and there is no handedness to get wrong.
TOP_CONTROLS_W = 41;   // measured, across the whole block
TOP_CONTROLS_D = 15;   // measured, front to back
TOP_CONTROLS_X = 0;    // centred: measured 27.5mm from a side edge, of 55
TOP_CONTROLS_Y = -6.5; // measured 15mm back from the front... i.e. from
                        // the frame-side edge, of 43
// Extra opening beyond the block itself. The lid's edge should not
// crowd the outermost button, and the enclosure can shift by
// FIT_CLEARANCE inside the cavity, so the hole has to absorb that too.
TOP_CONTROLS_REACH = 3;
LID_CUTOUT_R = 3;  // corner radius of that cutout

// ---------------- SD card access ----------------
// The SD card sits on the enclosure's bottom face, and it has to be
// reachable every ride. Rather than unbolting the lid and lifting the
// whole enclosure out each time, the bottom collar's floor opens under
// the card slot, so the card ejects downward into open air.
//
// Give the slot's own position below and the opening derives itself:
// it reaches SD_REACH past the slot in each direction, then pulls back
// to leave SD_EDGE_MARGIN of floor against the cavity walls. Cut the
// matching hole in the floor foam pad, so the pad never covers the slot.
//
// Two things to weigh before opening it up. This face points down the
// downtube, straight into road spray, so anything you open here is a
// direct path to the card slot. And the card has to clear the floor
// plus the foam pad, about 7mm, before you can pinch it -- so make the
// opening wide enough for a fingertip, not just for the card.
// Slot position, measured on the enclosure's bottom face, from the
// middle of that face. +Y is forward, away from the frame.
SD_SLOT_X = 15;    // 42.5mm in from a side edge, of 55
SD_SLOT_Y = 9.5;   // 31mm in from the frame-side edge, of 43
//
// CHECK THIS ONE BEFORE PRINTING. The slot is 15mm off centre, so the
// side matters, and "left edge" depends on which way the enclosure was
// held when it got measured. Stand the enclosure upright with the
// display facing you: +1 puts the slot toward your left hand, -1
// toward your right.
SD_SLOT_SIDE = -1;
SD_REACH = 12;       // how far the opening reaches past the slot, so a
                      // finger or tweezers can get to the card
SD_EDGE_MARGIN = 4;  // floor left between the opening and the cavity wall
SD_ACCESS_R = 3;     // corner radius of the opening
SD_ACCESS_FLARE = 3; // 45 degree widening on the underside, for reach.
                      // Set equal to FLOOR_THICK so the flare uses the
                      // whole floor: the opening the foam pad sees stays
                      // small, while the opening your finger meets is as
                      // wide as the floor allows. Do not exceed
                      // FLOOR_THICK.

// ---------------- Bottle-cage bolt pattern ----------------
BOLT_SPACING  = 64;  // standard 2-bolt spacing, center to center
BOLT_HOLE_DIA = 5.5; // M5 clearance
WIGGLE        = 4;   // extra slot length beyond the bolt hole (each slot)
SPINE_WIDTH   = 22;
SPINE_THICK   = 10;  // solid backing behind the counterbore below, for
                      // the button-head-plus-washer stack

// Real bottle-cage bolt hardware (measured): a button head plus washer,
// used as one stack.
M5_HEAD_WASHER_OD  = 10; // widest point of the head+washer stack
M5_HEAD_WASHER_LEN = 6;  // length of that stack, base of head to washer face

// Counterbore for the bolt head, on the front face (the same side the
// cradle collars attach to). Most bottle-cage bolts are socket- or
// button-head, not the tapered kind a true countersink suits, so this
// is a straight cylindrical recess, not a cone.
BOLT_HEAD_DIA_CLEARANCE = 0.5;
BOLT_HEAD_LEN_CLEARANCE = 0.3;
COUNTERBORE_DIA   = M5_HEAD_WASHER_OD + BOLT_HEAD_DIA_CLEARANCE;
COUNTERBORE_DEPTH = M5_HEAD_WASHER_LEN + BOLT_HEAD_LEN_CLEARANCE;

// How much solid spine to leave between a collar's edge and the bolt
// head that has to stay reachable beside it.
BOLT_CLEAR_MARGIN = 1;

// ---------------- Collar-to-spine fasteners ----------------
// The spine and both collars print separately and get joined
// afterward. These are through-holes for an M3 cap-head screw through
// each collar's brace, through the spine, into a nut pressed into a
// pocket on the spine's back (frame-facing) face -- see nut_pocket().
// A clearance hole this size gives a plastic self-tapping screw
// nothing to bite into, so a captive nut carries the clamping load.
JOINT_HOLE_DIA     = 3.2;  // M3 clearance
JOINT_HOLE_SPACING = 12;   // between the two fasteners per collar, centered on X=0

// The screw goes in from the cavity side, so its head needs a recess
// or it stands proud into the enclosure's path. Cap-head screws have
// a flat-bottomed cylindrical head, so this is a straight counterbore.
CAP_HEAD_DIA = 5.5; // measured, across the screw head
CAP_HEAD_LEN = 4;   // measured, head length

JOINT_COUNTERBORE_DIA   = CAP_HEAD_DIA + BOLT_HEAD_DIA_CLEARANCE;
JOINT_COUNTERBORE_DEPTH = CAP_HEAD_LEN + BOLT_HEAD_LEN_CLEARANCE;

// A hex nut pressed into a pocket on the spine's back face, captive so
// it can't spin when the screw is tightened from the collar side.
NUT_ACROSS_FLATS    = 5.5; // measured, flat-to-flat
NUT_THICK           = 2.4; // measured
NUT_POCKET_CLEARANCE = 0.2; // oversize on the flats for a snug press fit
NUT_POCKET_DEPTH_CLEARANCE = 1.6; // extra depth so the nut seats fully.
                                    // Deliberately generous: it pulls the
                                    // nut closer to the screw head, which
                                    // is what lets a stock M3x10 engage the
                                    // whole nut and still stay clear of the
                                    // frame. The screw pulls the nut onto
                                    // the shoulder at the pocket's inner
                                    // end, so the spare depth sits behind
                                    // the nut and just gives the screw tip
                                    // somewhere to go.

// ---------------- Braces ----------------
// Neither collar can be bolted through its own wall any more. The
// walls are closed, so a screw head inside the cavity is unreachable:
// the screw runs front-to-back, and there is no longer a front opening
// to put a driver through.
//
// So each collar extends its back wall past itself as a brace, and
// puts its two screws in the open span between the collars, where a
// driver reaches them straight on. The top collar braces downward,
// the bottom collar upward. Both land inside the spine's bolted span,
// which is also the stiffest place to anchor them -- the unsupported
// tip of the spine flexes.
//
// How far each brace reaches is derived, not fixed: each M5 bolt's
// counterbore is a big elongated recess, and a brace has to clear it
// with real spine material to spare. Landing an M3 counterbore inside
// or at the edge of that recess leaves almost nothing between the two.
JOINT_COUNTERBORE_CLEARANCE = 3; // gap between the M3 joint counterbore's
                                   // edge and the M5 counterbore's edge
JOINT_HOLE_EDGE_MARGIN      = 4;  // keeps the fastener this far from the
                                   // brace's own free tip

// A window through each brace, over that brace's own M5 bolt, so the
// bolt stays reachable once the collar is on.
WINDOW_CLEARANCE = 1; // extra diameter beyond COUNTERBORE_DIA, so minor
                        // print/assembly misalignment still leaves the
                        // bolt fully reachable

// ---------------- Fit-check reference hardware ----------------
// Stand-in M5 bottle-cage bolts, M3 collar-to-spine screws, and their
// nuts, sized and positioned to match the real fasteners and the
// recesses cut for them, so a "full" render shows whether anything
// actually collides. Translucent -- for F5 preview only, excluded
// from render/export.
M5_BOLT_SHANK_DIA = 5;  // nominal M5 shank -- thinner than the 5.5mm
                          // clearance hole, so it visibly passes through
M5_BOLT_ENGAGE    = 15; // shank length shown past the spine's back face
M3_SCREW_ENGAGE   = 8;  // shank length shown past the counterbore

// ---------------- Which piece to render ----------------
// "full" | "mount" | "cradle_bottom" | "cradle_top" | "lid"
RENDER = "full";

$fn = 48;

// ==================== derived ====================
// ---- cavity ----
// Front-to-back: the back pad stands FOAM_POCKET_DEPTH shy of its
// free thickness, and the enclosure squashes what is left by
// FOAM_BACK_CRUSH, which presses it against the front wall.
back_pad_proud = FOAM_THICK - FOAM_POCKET_DEPTH - FOAM_BACK_CRUSH;
lid_pad_proud  = FOAM_THICK - FOAM_POCKET_DEPTH - FOAM_V_CRUSH;
floor_pad_work = FOAM_THICK - FOAM_V_CRUSH; // floor pad sits in no pocket

inner_w  = ENCL_WIDTH + 2*FIT_CLEARANCE;
inner_d  = ENCL_DEPTH + back_pad_proud;
outer_w  = inner_w + 2*WALL;
outer_d  = inner_d + 2*WALL;

back_pad_w = inner_w - 2*FOAM_PAD_SIDE_MARGIN;

// The enclosure is pressed onto the front wall by the back pad, so it
// does not sit centred in the cavity. Anything measured on the
// enclosure's own faces has to be shifted by this to land in the
// cavity's frame.
encl_y_offset = back_pad_proud + ENCL_DEPTH/2 - inner_d/2;

// ---- lid cutout, over the top-face controls ----
lid_cutout_w = TOP_CONTROLS_W + 2*TOP_CONTROLS_REACH;
lid_cutout_d = TOP_CONTROLS_D + 2*TOP_CONTROLS_REACH;
lid_cutout_x = TOP_CONTROLS_X;
lid_cutout_y = TOP_CONTROLS_Y + encl_y_offset;

// ---- SD access opening in the floor ----
// Reach out from the slot in every direction, then pull back to leave
// SD_EDGE_MARGIN of floor against the cavity walls. The slot sits well
// off centre, so the opening ends up asymmetric about it -- that is
// correct, and it is where the finger room has to come from.
sd_slot_cx = SD_SLOT_SIDE * SD_SLOT_X;
sd_slot_cy = SD_SLOT_Y + encl_y_offset;
sd_x_lo = max(sd_slot_cx - SD_REACH, -inner_w/2 + SD_EDGE_MARGIN);
sd_x_hi = min(sd_slot_cx + SD_REACH,  inner_w/2 - SD_EDGE_MARGIN);
sd_y_lo = max(sd_slot_cy - SD_REACH, -inner_d/2 + SD_EDGE_MARGIN);
sd_y_hi = min(sd_slot_cy + SD_REACH,  inner_d/2 - SD_EDGE_MARGIN);
sd_access_w = sd_x_hi - sd_x_lo;
sd_access_d = sd_y_hi - sd_y_lo;
sd_access_x = (sd_x_hi + sd_x_lo) / 2;
sd_access_y = (sd_y_hi + sd_y_lo) / 2;

lid_w       = outer_w + 2*CORNER_BOSS;
lid_d       = outer_d + 2*CORNER_BOSS;
lid_screw_x = outer_w/2 + CORNER_BOSS - LID_SCREW_INSET;
lid_screw_y = outer_d/2 + CORNER_BOSS - LID_SCREW_INSET;

// ---- the vertical stack, bottom to top ----
// Everything above the cavity floor is set by the foam, not guessed:
// floor pad, enclosure, lid pad, lid.
floor_top_z  = RING_MARGIN_BOTTOM;              // top of the solid floor
encl_bottom_z = floor_top_z + floor_pad_work;
encl_top_z   = encl_bottom_z + ENCL_LEN;
lid_seat_z   = encl_top_z + lid_pad_proud;      // the top collar's top face
cage_len     = lid_seat_z + LID_THICK;          // spine length

bottom_ring_bottom_z = floor_top_z - FLOOR_THICK;
bottom_ring_top_z    = floor_top_z + RING_HEIGHT;
top_ring_bottom_z    = lid_seat_z - RING_HEIGHT;

// how far a collar's local Y=0 sits from the spine's front face, so
// its back wall overlaps the spine cleanly
ring_y_offset = SPINE_THICK/2 + outer_d/2 - 0.5;

// ---- bottle-cage bolts ----
// Centred in the open span between the two collars, not on the spine.
// Both bolt heads have to stay reachable there, and that span is the
// tightest constraint in the whole design: 64mm of bolt spacing plus
// two bolt heads has to fit inside the enclosure's length minus both
// collars.
gap_center_z  = (bottom_ring_top_z + top_ring_bottom_z) / 2;
bottom_bolt_z = gap_center_z - BOLT_SPACING/2;
top_bolt_z    = gap_center_z + BOLT_SPACING/2;

// solid spine left between a collar edge and the nearer bolt head
bolt_clearance = (bottom_bolt_z - COUNTERBORE_DIA/2) - bottom_ring_top_z;

// ---- collar-to-spine joints ----
// Each sits just clear of its own bolt's counterbore recess.
top_bolt_counterbore_z_min = top_bolt_z - WIGGLE/2 - COUNTERBORE_DIA/2;
top_ring_joint_z = top_bolt_counterbore_z_min
                     - JOINT_COUNTERBORE_CLEARANCE - JOINT_COUNTERBORE_DIA/2;

bottom_bolt_counterbore_z_max = bottom_bolt_z + WIGGLE/2 + COUNTERBORE_DIA/2;
bottom_ring_joint_z = bottom_bolt_counterbore_z_max
                     + JOINT_COUNTERBORE_CLEARANCE + JOINT_COUNTERBORE_DIA/2;

BRACE_DROP = top_ring_bottom_z - top_ring_joint_z + JOINT_HOLE_EDGE_MARGIN;
BRACE_RISE = bottom_ring_joint_z + JOINT_HOLE_EDGE_MARGIN - bottom_ring_top_z;

// ---- foam cutting list, echoed at render time ----
echo(str("foam floor pad  : ", inner_w, " x ", inner_d, " x ", FOAM_THICK));
echo(str("foam lid pad    : ", inner_w, " x ", inner_d, " x ", FOAM_THICK));
echo(str("foam back pad, bottom collar: ", back_pad_w, " x ", RING_HEIGHT, " x ", FOAM_THICK));
echo(str("foam back pad, top collar   : ", back_pad_w, " x ", RING_HEIGHT - BACK_PAD_LEDGE, " x ", FOAM_THICK));
echo(str("cut each pad about 1mm oversize on width and height, and press it in"));
echo(str("  lid pad: cut a ", lid_cutout_w, " x ", lid_cutout_d,
         " hole, centred ", -lid_cutout_y, "mm toward the frame side"));
echo(str("  floor pad: cut a ", sd_access_w, " x ", sd_access_d,
         " hole to match the floor opening"));
echo(str("lid cutout over controls: ", lid_cutout_w, " x ", lid_cutout_d));
echo(str("SD floor opening: ", sd_access_w, " x ", sd_access_d,
         ", flaring to ", sd_access_w + 2*SD_ACCESS_FLARE, " x ",
         sd_access_d + 2*SD_ACCESS_FLARE, " at the underside"));
echo(str("collar outside : ", outer_w, " x ", outer_d, ", lid ", lid_w, " x ", lid_d));
echo(str("spine length   : ", cage_len));
echo(str("spine between bolt head and collar edge: ", bolt_clearance, "mm -- must stay positive"));

// ---- screw lengths, derived from the stack each screw passes through ----
// Collar-to-spine: under the head there is the material left behind the
// counterbore, then the spine, and the captive nut sits in the last
// stretch of that. The screw must reach through the nut but must not
// reach the spine's back face, which lies flat on the frame.
joint_grip       = (WALL - JOINT_COUNTERBORE_DEPTH) + SPINE_THICK;
nut_pocket_depth = NUT_THICK + NUT_POCKET_DEPTH_CLEARANCE;
nut_near_face    = joint_grip - nut_pocket_depth;
nut_far_face     = nut_near_face + NUT_THICK;
echo(str("M3 collar-to-spine screw: needs ", nut_far_face, "mm min under the head",
         " (full nut), ", joint_grip, "mm max (or it stands proud of the frame face)"));
// Lid: the screw crosses the lid, then the solid boss above the nut
// slot, then the nut itself. Longer is harmless -- the hole runs on
// through the boss.
lid_screw_min = LID_THICK + LID_NUT_DEPTH + NUT_THICK;
echo(str("M3 lid screw: needs ", lid_screw_min, "mm min under the head (full nut), ",
         LID_THICK + RING_HEIGHT, "mm max"));

// ==================== modules ====================

// Transparent stand-in for the real enclosure, for fit-checking in the
// F5 preview only -- the leading "%" excludes it from render/export.
module enclosure_reference() {
  %translate([-ENCL_WIDTH/2, ring_y_offset - inner_d/2 + back_pad_proud, encl_bottom_z])
    cube([ENCL_WIDTH, ENCL_DEPTH, ENCL_LEN]);
}

// Stand-in foam pads, same idea: floor, lid, and one back pad per
// collar, drawn at their squashed thickness so the preview shows the
// real stack rather than the free thickness.
module foam_reference() {
  // floor pad
  %translate([-inner_w/2, ring_y_offset - inner_d/2, floor_top_z])
    cube([inner_w, inner_d, floor_pad_work]);
  // lid pad
  %translate([-inner_w/2, ring_y_offset - inner_d/2, encl_top_z])
    cube([inner_w, inner_d, lid_pad_proud + FOAM_POCKET_DEPTH]);
  // back pads
  %translate([-back_pad_w/2, ring_y_offset - inner_d/2 - FOAM_POCKET_DEPTH, floor_top_z])
    cube([back_pad_w, FOAM_POCKET_DEPTH + back_pad_proud, RING_HEIGHT]);
  %translate([-back_pad_w/2, ring_y_offset - inner_d/2 - FOAM_POCKET_DEPTH,
              top_ring_bottom_z + BACK_PAD_LEDGE])
    cube([back_pad_w, FOAM_POCKET_DEPTH + back_pad_proud, RING_HEIGHT - BACK_PAD_LEDGE]);
}

// Fake M5 bottle-cage bolts, M3 collar-to-spine screws, and those
// nuts -- translucent, F5-preview-only fit check.
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

// Counterbore recess for one slot, on the spine's front face, sized to
// the same elongation as the slot below it so the bolt head can sit
// recessed anywhere along the adjustable range.
module bolt_counterbore() {
  hull() {
    translate([0, SPINE_THICK/2 - COUNTERBORE_DEPTH,  WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = COUNTERBORE_DEPTH + 1, d = COUNTERBORE_DIA);
    translate([0, SPINE_THICK/2 - COUNTERBORE_DEPTH, -WIGGLE/2])
      rotate([-90, 0, 0]) cylinder(h = COUNTERBORE_DEPTH + 1, d = COUNTERBORE_DIA);
  }
}

// Hex pocket for a captive M3 nut, cut into the spine's back (frame-
// facing) face. $fn=6 gives a hexagon circumscribed by the cylinder's
// diameter, so the diameter has to be the across-flats size divided by
// cos(30) to come out to the right across-flats width.
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
    // collar-to-spine fastener holes, one pair per collar, each with a
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

// Window through a brace, over that brace's own M5 bolt, so the bolt
// stays reachable once the collar is bolted on. Matches the
// counterbore's elongated slot shape, oversized by WINDOW_CLEARANCE,
// and clamped to the brace's own span so it cannot nick the collar
// wall above or below it.
module brace_window(bolt_z_local, z_lo, z_hi) {
  window_dia = COUNTERBORE_DIA + WINDOW_CLEARANCE;
  intersection() {
    translate([-outer_w, -outer_d, z_lo]) cube([2*outer_w, 2*outer_d, z_hi - z_lo]);
    hull() {
      translate([0, -outer_d/2 - 1, bolt_z_local + WIGGLE/2])
        rotate([-90, 0, 0]) cylinder(h = WALL + 2, d = window_dia);
      translate([0, -outer_d/2 - 1, bolt_z_local - WIGGLE/2])
        rotate([-90, 0, 0]) cylinder(h = WALL + 2, d = window_dia);
    }
  }
}

// One cradle collar: a closed rectangular ring around the enclosure's
// cross-section. Sits with its own bottom at local Z=0, centered on
// X=0/Y=0. The cavity is always RING_HEIGHT tall; a floor, if any,
// sits below it.
//
// floor=true adds a solid floor under the cavity, with drain holes.
// Use it on the bottom collar only.
//
// brace_drop extends the back wall below the collar, brace_rise above
// it, so the collar's two screws land in the open span between the
// collars where a driver can reach them. Each collar uses one or the
// other: top collar drops, bottom collar rises.
//
// bolt_z_local is that brace's own M5 bolt, in the collar's local
// frame, for the access window.
//
// lid_bosses=true thickens the four corners and drills the lid's
// pilot holes. Top collar only.
module cradle_ring(floor = false, brace_drop = 0, brace_rise = 0,
                   bolt_z_local = 0, lid_bosses = false) {
  floor_h = floor ? FLOOR_THICK : 0;
  body_h  = floor_h + RING_HEIGHT;
  brace_w = JOINT_HOLE_SPACING + JOINT_COUNTERBORE_DIA + 4;
  joint_z = brace_drop > 0 ? -brace_drop + JOINT_HOLE_EDGE_MARGIN
                           : body_h + brace_rise - JOINT_HOLE_EDGE_MARGIN;
  // the back pad's pocket is closed at the bottom either way: by the
  // floor on the bottom collar, by a ledge on the top one
  pocket_z0 = floor ? floor_h : BACK_PAD_LEDGE;

  difference() {
    union() {
      translate([-outer_w/2, -outer_d/2, 0])
        cube([outer_w, outer_d, body_h]);
      if (lid_bosses)
        for (sx = [-1, 1]) for (sy = [-1, 1])
          translate([sx > 0 ? outer_w/2 + CORNER_BOSS - BOSS_SIZE : -(outer_w/2 + CORNER_BOSS),
                     sy > 0 ? outer_d/2 + CORNER_BOSS - BOSS_SIZE : -(outer_d/2 + CORNER_BOSS),
                     0])
            cube([BOSS_SIZE, BOSS_SIZE, body_h]);
      if (brace_drop > 0)
        translate([-brace_w/2, -outer_d/2, -brace_drop])
          cube([brace_w, WALL, brace_drop]);
      if (brace_rise > 0)
        translate([-brace_w/2, -outer_d/2, body_h])
          cube([brace_w, WALL, brace_rise]);
    }

    // the enclosure's cavity, open at the top
    translate([-inner_w/2, -inner_d/2, floor_h])
      cube([inner_w, inner_d, RING_HEIGHT + 1]);

    // lead-in flare at the cavity's mouth
    hull() {
      translate([-inner_w/2, -inner_d/2, body_h - ENTRY_CHAMFER])
        cube([inner_w, inner_d, 0.01]);
      translate([-inner_w/2 - ENTRY_CHAMFER, -inner_d/2 - ENTRY_CHAMFER, body_h + 0.01])
        cube([inner_w + 2*ENTRY_CHAMFER, inner_d + 2*ENTRY_CHAMFER, 0.01]);
    }

    // pocket for the back foam pad, milled into the back wall
    translate([-back_pad_w/2, -inner_d/2 - FOAM_POCKET_DEPTH, pocket_z0])
      cube([back_pad_w, FOAM_POCKET_DEPTH, body_h - pocket_z0 + 0.01]);

    // drain holes through the floor
    if (floor)
      for (sx = [-1, 1]) for (sy = [-1, 1])
        translate([sx * inner_w/4, sy * inner_d/4, -1])
          cylinder(h = floor_h + 2, d = DRAIN_DIA);

    // SD card access through the floor, with a 45 degree flare on the
    // underside so a finger or tweezers can reach the card. The card
    // only ejects a couple of mm, and it still has the floor and the
    // foam pad to clear, so the reach matters more than the width.
    if (floor && sd_access_w > 0 && sd_access_d > 0) {
      // straight through, above the flare
      hull()
        for (sx = [-1, 1]) for (sy = [-1, 1])
          translate([sd_access_x + sx * (sd_access_w/2 - SD_ACCESS_R),
                     sd_access_y + sy * (sd_access_d/2 - SD_ACCESS_R),
                     SD_ACCESS_FLARE])
            cylinder(h = floor_h + 1, r = SD_ACCESS_R);
      // the flare itself: wide at the underside, narrowing to the
      // opening above it
      hull() {
        sd_r2 = SD_ACCESS_R + SD_ACCESS_FLARE;
        for (sx = [-1, 1]) for (sy = [-1, 1]) {
          translate([sd_access_x + sx * (sd_access_w/2 + SD_ACCESS_FLARE - sd_r2),
                     sd_access_y + sy * (sd_access_d/2 + SD_ACCESS_FLARE - sd_r2),
                     -1])
            cylinder(h = 1.01, r = sd_r2);
          translate([sd_access_x + sx * (sd_access_w/2 - SD_ACCESS_R),
                     sd_access_y + sy * (sd_access_d/2 - SD_ACCESS_R),
                     SD_ACCESS_FLARE])
            cylinder(h = 0.01, r = SD_ACCESS_R);
        }
      }
    }

    // fastener holes through the brace, joining this separately printed
    // collar to the spine -- must match spine()'s hole Z. Each gets a
    // counterbore on the cavity-facing side for the screw's cap head.
    for (s = [-1, 1]) {
      translate([s * JOINT_HOLE_SPACING/2, 0, joint_z])
        rotate([-90, 0, 0])
          cylinder(h = outer_d + 2, d = JOINT_HOLE_DIA, center = true);
      translate([s * JOINT_HOLE_SPACING/2, -inner_d/2 - JOINT_COUNTERBORE_DEPTH, joint_z])
        rotate([-90, 0, 0])
          cylinder(h = JOINT_COUNTERBORE_DEPTH, d = JOINT_COUNTERBORE_DIA);
    }

    // access window over this brace's own M5 bolt
    if (brace_drop > 0) brace_window(bolt_z_local, -brace_drop, 0);
    if (brace_rise > 0) brace_window(bolt_z_local, body_h, body_h + brace_rise);

    // lid screws: a clearance hole down through the boss, opening into
    // a slot that holds a captive M3 nut. The nut slides in from the
    // boss's outer side face, and the screw pulls it up against the
    // solid LID_NUT_DEPTH of boss above it.
    if (lid_bosses)
      for (sx = [-1, 1]) for (sy = [-1, 1]) {
        nut_w    = NUT_ACROSS_FLATS + LID_NUT_SLOT_CLEARANCE;
        slot_top = body_h - LID_NUT_DEPTH;
        slot_h   = NUT_THICK + NUT_POCKET_CLEARANCE;
        // reach far enough in to centre the nut on the screw, measuring
        // across the hex's corners, not its flats
        slot_len = LID_SCREW_INSET + (NUT_ACROSS_FLATS/cos(30))/2 + 0.3;
        // through the whole boss, not just down to the nut: it stops the
        // screw bottoming out on the slot's floor, and it drains the slot
        translate([sx * lid_screw_x, sy * lid_screw_y, -1])
          cylinder(h = body_h + 2, d = JOINT_HOLE_DIA);
        translate([sx > 0 ? outer_w/2 + CORNER_BOSS - slot_len : -(outer_w/2 + CORNER_BOSS),
                   sy * lid_screw_y - nut_w/2,
                   slot_top - slot_h])
          cube([slot_len + 1, nut_w, slot_h]);
      }
  }
}

// The roof. A flat plate that bolts down onto the top collar and
// squashes the lid foam pad onto the enclosure's top face. Its rim
// lands on the collar's top rim, which is a hard stop: the foam
// cannot be crushed past FOAM_V_CRUSH however hard the screws go.
// Built with its underside at local Z=0.
module lid() {
  difference() {
    translate([-lid_w/2, -lid_d/2, 0]) cube([lid_w, lid_d, LID_THICK]);

    // pocket for the lid foam pad, on the underside
    translate([-inner_w/2, -inner_d/2, -1])
      cube([inner_w, inner_d, FOAM_POCKET_DEPTH + 1]);

    // notch for the spine, which runs up past the back of the collar
    // to the top of the lid
    translate([-(SPINE_WIDTH/2 + 0.5), -lid_d/2 - 1, -1])
      cube([SPINE_WIDTH + 1,
            (SPINE_THICK/2 - ring_y_offset) + 0.5 + lid_d/2 + 1,
            LID_THICK + 2]);

    // screw clearance holes, over the top collar's corner bosses
    for (sx = [-1, 1]) for (sy = [-1, 1])
      translate([sx * lid_screw_x, sy * lid_screw_y, -1])
        cylinder(h = LID_THICK + 2, d = JOINT_HOLE_DIA);

    // cutout over the top-face controls
    if (lid_cutout_w > 0 && lid_cutout_d > 0)
      hull()
        for (sx = [-1, 1]) for (sy = [-1, 1])
          translate([lid_cutout_x + sx * (lid_cutout_w/2 - LID_CUTOUT_R),
                     lid_cutout_y + sy * (lid_cutout_d/2 - LID_CUTOUT_R), -1])
            cylinder(h = LID_THICK + 2, r = LID_CUTOUT_R);
  }
}

// The whole cage: spine, both collars, lid.
module full_cage() {
  union() {
    spine();
    translate([0, ring_y_offset, bottom_ring_bottom_z])
      cradle_ring(floor = true,
                  brace_rise = BRACE_RISE,
                  bolt_z_local = bottom_bolt_z - bottom_ring_bottom_z);
    translate([0, ring_y_offset, top_ring_bottom_z])
      cradle_ring(floor = false,
                  brace_drop = BRACE_DROP,
                  bolt_z_local = top_bolt_z - top_ring_bottom_z,
                  lid_bosses = true);
  }
  translate([0, ring_y_offset, lid_seat_z]) lid();
}

// ==================== render dispatch ====================
if (RENDER == "full") {
  full_cage();
  enclosure_reference();
  foam_reference();
  fastener_reference();
} else if (RENDER == "mount") {
  // Standing up, this is 22x10mm at the base and cage_len tall -- a
  // tall, thin part that's prone to toppling and poor bed adhesion.
  // Lay it on its long face instead: low, wide, and stable. The bolt
  // holes print as clean vertical bores this way, so it's a win either
  // way, not just a printability compromise.
  translate([0, 0, SPINE_THICK/2])
    rotate([90, 0, 0])
      spine();
} else if (RENDER == "cradle_bottom") {
  // Upright, floor on the bed. Every wall is vertical, the brace is a
  // fin standing on the back wall, and the floor gives a big first
  // layer. Nothing overhangs.
  cradle_ring(floor = true,
              brace_rise = BRACE_RISE,
              bolt_z_local = bottom_bolt_z - bottom_ring_bottom_z);
} else if (RENDER == "cradle_top") {
  // Upside down, top face on the bed. Printed the right way up it
  // would stand on the brace's thin tip; printed on its back, the
  // now-closed front wall would be a 56mm bridge over the cavity.
  // Flipped, the cavity is a plain vertical tunnel, the brace is a
  // fin standing on the back wall, and the lid's seating face comes
  // off the bed flat.
  translate([0, 0, RING_HEIGHT])
    rotate([180, 0, 0])
      cradle_ring(floor = false,
                  brace_drop = BRACE_DROP,
                  bolt_z_local = top_bolt_z - top_ring_bottom_z,
                  lid_bosses = true);
} else if (RENDER == "lid") {
  // Upside down as well, so the foam pocket opens upward instead of
  // bridging over its own ceiling.
  translate([0, 0, LID_THICK])
    rotate([180, 0, 0])
      lid();
} else {
  echo(str("Unknown RENDER value: ", RENDER,
           " -- use \"full\", \"mount\", \"cradle_bottom\", \"cradle_top\", or \"lid\""));
}
