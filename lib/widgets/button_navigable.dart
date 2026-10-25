/// Implemented by any screen that wants to respond to the physical case
/// buttons (Up / Down / Call) while it's the topmost screen.
///
/// Home, Hang-up, and SOS are handled globally by [PhoneShellController]
/// and never reach the screen directly.
abstract class ButtonNavigable {
  void moveHighlightUp();
  void moveHighlightDown();
  void confirmHighlighted();
}
