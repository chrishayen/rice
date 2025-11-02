// GTK4 and Adwaita bindings using Zig's C import
const std = @import("std");

pub const c = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("adwaita.h");
    @cInclude("cairo.h");
});

// Re-export commonly used types for convenience
pub const GtkApplication = c.GtkApplication;
pub const GtkWidget = c.GtkWidget;
pub const GtkWindow = c.GtkWindow;
pub const GtkBox = c.GtkBox;
pub const GtkButton = c.GtkButton;
pub const GtkToggleButton = c.GtkToggleButton;
pub const GtkLabel = c.GtkLabel;
pub const GtkPaned = c.GtkPaned;
pub const GtkScrolledWindow = c.GtkScrolledWindow;
pub const GtkFrame = c.GtkFrame;
pub const GtkDrawingArea = c.GtkDrawingArea;
pub const GtkColorButton = c.GtkColorButton;
pub const GtkScale = c.GtkScale;
pub const GtkDropDown = c.GtkDropDown;
pub const GtkStringList = c.GtkStringList;
pub const GtkGestureDrag = c.GtkGestureDrag;
pub const GtkNotebook = c.GtkNotebook;

// Adwaita types
pub const AdwApplication = c.AdwApplication;
pub const AdwApplicationWindow = c.AdwApplicationWindow;
pub const AdwHeaderBar = c.AdwHeaderBar;
pub const AdwTabView = c.AdwTabView;
pub const AdwTabBar = c.AdwTabBar;
pub const AdwTabPage = c.AdwTabPage;
pub const AdwPreferencesGroup = c.AdwPreferencesGroup;
pub const AdwActionRow = c.AdwActionRow;
pub const AdwWindowTitle = c.AdwWindowTitle;

// GDK types
pub const GdkRGBA = c.GdkRGBA;

// Cairo types
pub const cairo_t = c.cairo_t;
pub const cairo_surface_t = c.cairo_surface_t;

// Constants
pub const GTK_ORIENTATION_VERTICAL = c.GTK_ORIENTATION_VERTICAL;
pub const GTK_ORIENTATION_HORIZONTAL = c.GTK_ORIENTATION_HORIZONTAL;
pub const G_APPLICATION_DEFAULT_FLAGS = c.G_APPLICATION_DEFAULT_FLAGS;
