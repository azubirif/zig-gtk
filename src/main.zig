const std = @import("std");

const gtk = @cImport({
    @cInclude("gtk/gtk.h");
});

const AppError = error{
    GtkApplicationCreateFailed,
    SignalConnectFailed,
    ApplicationRunFailed,
};

fn onActivate(app_ptr: ?*gtk.GtkApplication, _: ?*anyopaque) callconv(.c) void {
    const app = app_ptr orelse return;

    const window = gtk.gtk_application_window_new(app);
    const gtk_window: *gtk.GtkWindow = @ptrCast(window);
    gtk.gtk_window_set_title(gtk_window, "Zig GTK Starter");
    gtk.gtk_window_set_default_size(gtk_window, 480, 320);

    const label = gtk.gtk_label_new("Hello from Zig + GTK!");
    gtk.gtk_widget_set_margin_top(label, 24);
    gtk.gtk_widget_set_margin_bottom(label, 24);
    gtk.gtk_widget_set_margin_start(label, 24);
    gtk.gtk_widget_set_margin_end(label, 24);

    gtk.gtk_window_set_child(gtk_window, label);
    gtk.gtk_window_present(gtk_window);
}

pub fn main() AppError!void {
    const app = gtk.gtk_application_new("com.example.ziggtk", gtk.G_APPLICATION_FLAGS_NONE) orelse
        return error.GtkApplicationCreateFailed;
    const any_app: *anyopaque = @ptrCast(app);
    defer gtk.g_object_unref(any_app);

    const activate_cb: gtk.GCallback = @ptrCast(&onActivate);
    const handler_id = gtk.g_signal_connect_data(
        any_app,
        "activate",
        activate_cb,
        null,
        null,
        0,
    );
    if (handler_id == 0) {
        return error.SignalConnectFailed;
    }

    const g_app: *gtk.GApplication = @ptrCast(app);
    const status = gtk.g_application_run(g_app, 0, null);
    if (status != 0) {
        return error.ApplicationRunFailed;
    }
}

test "placeholder" {
    try std.testing.expect(true);
}
