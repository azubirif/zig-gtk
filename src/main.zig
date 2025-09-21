const std = @import("std");
const file_browser = @import("core/file_browser.zig");

const gtk = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("gio/gio.h");
});

const AppError = error{
    GtkApplicationCreateFailed,
    SignalConnectFailed,
    ApplicationRunFailed,
};

const c_allocator = std.heap.c_allocator;

const AppState = struct {
    allocator: std.mem.Allocator,
    window: *gtk.GtkWindow,
    dir_label: *gtk.GtkLabel,
    list_box: *gtk.GtkListBox,
    file_names: ?file_browser.FileNameList = null,

    fn deinit(self: *AppState) void {
        if (self.file_names) |*list| {
            list.deinit();
            self.file_names = null;
        }
    }

    fn clearList(self: *AppState) void {
        const list_box_widget: *gtk.GtkWidget = @ptrCast(@alignCast(self.list_box));
        var child = gtk.gtk_widget_get_first_child(list_box_widget);
        while (child) |row_widget| {
            const next = gtk.gtk_widget_get_next_sibling(row_widget);
            gtk.gtk_list_box_remove(self.list_box, row_widget);
            child = next;
        }
    }

    fn showListMessage(self: *AppState, message: []const u8) void {
        if (self.file_names) |*existing| {
            existing.deinit();
            self.file_names = null;
        }
        self.clearList();
        self.appendRow(message) catch {};
    }

    fn populateList(self: *AppState, names: []const []const u8) !void {
        if (names.len == 0) {
            try self.appendRow("No files found");
            return;
        }

        for (names) |name| {
            try self.appendRow(name);
        }
    }

    fn appendRow(self: *AppState, text: []const u8) !void {
        const widget = try createLabel(self.allocator, text);
        gtk.gtk_widget_set_margin_top(widget, 2);
        gtk.gtk_widget_set_margin_bottom(widget, 2);
        gtk.gtk_widget_set_halign(widget, gtk.GTK_ALIGN_START);
        gtk.gtk_list_box_append(self.list_box, widget);
    }

    fn setDirectory(self: *AppState, dir_path: []const u8) void {
        setLabelText(self.allocator, self.dir_label, dir_path) catch {
            self.showListMessage("Unable to display directory path");
            return;
        };

        self.clearList();
        if (self.file_names) |*existing| {
            existing.deinit();
            self.file_names = null;
        }

        var list = file_browser.listFileNames(self.allocator, dir_path) catch {
            self.showListMessage("Unable to read directory");
            return;
        };

        self.populateList(list.names()) catch {
            list.deinit();
            self.showListMessage("Unable to populate file list");
            return;
        };

        self.file_names = list;
    }
};

fn setLabelText(allocator: std.mem.Allocator, label: *gtk.GtkLabel, text: []const u8) error{OutOfMemory}!void {
    const buffer = try allocator.alloc(u8, text.len + 1);
    defer allocator.free(buffer);
    @memcpy(buffer[0..text.len], text);
    buffer[text.len] = 0;
    const c_str: [*:0]const u8 = @ptrCast(buffer.ptr);
    gtk.gtk_label_set_text(label, c_str);
}

fn createLabel(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}!*gtk.GtkWidget {
    const buffer = try allocator.alloc(u8, text.len + 1);
    defer allocator.free(buffer);
    @memcpy(buffer[0..text.len], text);
    buffer[text.len] = 0;
    const c_str: [*:0]const u8 = @ptrCast(buffer.ptr);
    return gtk.gtk_label_new(c_str);
}

fn destroyAppState(data: ?*anyopaque) callconv(.c) void {
    if (data) |ptr| {
        const typed_ptr: *align(1) AppState = @ptrCast(ptr);
        const state: *AppState = @alignCast(typed_ptr);
        state.deinit();
        c_allocator.destroy(state);
    }
}

fn getState(data: ?*anyopaque) ?*AppState {
    return if (data) |ptr| blk: {
        const typed_ptr: *align(1) AppState = @ptrCast(ptr);
        const state_ptr: *AppState = @alignCast(typed_ptr);
        break :blk state_ptr;
    } else null;
}

fn onChooseDirectoryClicked(_: ?*gtk.GtkButton, user_data: ?*anyopaque) callconv(.c) void {
    const state = getState(user_data) orelse return;
    openFileChooser(state);
}

fn openFileChooser(state: *AppState) void {
    const dialog_opt = gtk.gtk_file_chooser_native_new(
        "Select Directory",
        state.window,
        gtk.GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
        "Select",
        "Cancel",
    );
    const dialog = dialog_opt orelse return;

    const dialog_any: *anyopaque = @ptrCast(dialog);
    const callback: gtk.GCallback = @ptrCast(&onFileChooserResponse);
    const state_data: *anyopaque = @ptrCast(state);
    _ = gtk.g_signal_connect_data(
        dialog_any,
        "response",
        callback,
        state_data,
        null,
        0,
    );

    const native_dialog: *gtk.GtkNativeDialog = @ptrCast(@alignCast(dialog));
    gtk.gtk_native_dialog_show(native_dialog);
}

fn onFileChooserResponse(dialog_ptr: ?*gtk.GtkFileChooserNative, response_id: c_int, user_data: ?*anyopaque) callconv(.c) void {
    const dialog = dialog_ptr orelse return;
    const dialog_obj: *anyopaque = @ptrCast(dialog);
    defer gtk.g_object_unref(dialog_obj);

    const state = getState(user_data) orelse return;
    if (response_id != gtk.GTK_RESPONSE_ACCEPT) {
        return;
    }

    const chooser: *gtk.GtkFileChooser = @ptrCast(dialog);
    const file = gtk.gtk_file_chooser_get_file(chooser);
    if (file == null) {
        return;
    }
    const file_obj: *anyopaque = @ptrCast(file);
    defer gtk.g_object_unref(file_obj);

    const path_c = gtk.g_file_get_path(file);
    if (path_c == null) {
        return;
    }
    const path_ptr: *anyopaque = @ptrCast(path_c);
    defer gtk.g_free(path_ptr);

    const path = std.mem.span(path_c);
    state.setDirectory(path);
}

fn onActivate(app_ptr: ?*gtk.GtkApplication, _: ?*anyopaque) callconv(.c) void {
    const app = app_ptr orelse return;

    const window_widget = gtk.gtk_application_window_new(app);
    const window: *gtk.GtkWindow = @ptrCast(window_widget);
    gtk.gtk_window_set_title(window, "Zig GTK File Browser");
    gtk.gtk_window_set_default_size(window, 640, 480);

    const container = gtk.gtk_box_new(gtk.GTK_ORIENTATION_VERTICAL, 12);
    gtk.gtk_widget_set_margin_top(container, 12);
    gtk.gtk_widget_set_margin_bottom(container, 12);
    gtk.gtk_widget_set_margin_start(container, 12);
    gtk.gtk_widget_set_margin_end(container, 12);
    gtk.gtk_window_set_child(window, container);

    const choose_button = gtk.gtk_button_new_with_label("Choose Directory");
    gtk.gtk_widget_set_halign(choose_button, gtk.GTK_ALIGN_START);

    const path_label = gtk.gtk_label_new("No directory selected");
    gtk.gtk_widget_set_halign(path_label, gtk.GTK_ALIGN_START);

    const list_box_widget = gtk.gtk_list_box_new();
    const list_box: *gtk.GtkListBox = @ptrCast(list_box_widget);
    gtk.gtk_widget_set_vexpand(list_box_widget, 1);
    gtk.gtk_widget_set_hexpand(list_box_widget, 1);

    const box: *gtk.GtkBox = @ptrCast(container);
    gtk.gtk_box_append(box, choose_button);
    gtk.gtk_box_append(box, path_label);
    gtk.gtk_box_append(box, list_box_widget);

    const state = c_allocator.create(AppState) catch {
        gtk.gtk_widget_set_sensitive(choose_button, 0);
        gtk.gtk_list_box_append(list_box, gtk.gtk_label_new("Out of memory"));
        gtk.gtk_window_present(window);
        return;
    };
    state.* = .{
        .allocator = c_allocator,
        .window = window,
        .dir_label = @ptrCast(path_label),
        .list_box = list_box,
        .file_names = null,
    };
    state.showListMessage("Select a directory to list files");

    const window_obj: *gtk.GObject = @ptrCast(window_widget);
    const destroy_fn: gtk.GDestroyNotify = @ptrCast(&destroyAppState);
    const state_data: *anyopaque = @ptrCast(state);
    gtk.g_object_set_data_full(
        window_obj,
        "app-state",
        state_data,
        destroy_fn,
    );

    const button_obj: *anyopaque = @ptrCast(choose_button);
    const button_callback: gtk.GCallback = @ptrCast(&onChooseDirectoryClicked);
    _ = gtk.g_signal_connect_data(
        button_obj,
        "clicked",
        button_callback,
        state_data,
        null,
        0,
    );

    gtk.gtk_window_present(window);
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
