/// Avatar animation status, shared across features via core.
enum AvatarStatusAnimation {
  initial,
  leaving, // Horizontal slide out (left)
  coming, // Horizontal slide in (from left)
  transition, // General transition
  dropping, // Vertical slide down (for clothes change)
  rising, // Vertical slide up (return after clothes change)
}
