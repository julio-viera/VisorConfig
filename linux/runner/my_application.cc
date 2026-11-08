#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* launch_channel;
  GPtrArray* pending_launches;
  gboolean first_frame_rendered;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  self->first_frame_rendered = TRUE;
  for (guint i = 0; i < self->pending_launches->len; ++i) {
    auto* request = static_cast<FlValue*>(self->pending_launches->pdata[i]);
    fl_method_channel_invoke_method(self->launch_channel, "open", request,
                                    nullptr, nullptr, nullptr);
  }
  g_ptr_array_set_size(self->pending_launches, 0);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* existing =
      GTK_WINDOW(g_list_nth_data(
          gtk_application_get_windows(GTK_APPLICATION(application)), 0));
  if (existing != nullptr) {
    if (self->first_frame_rendered) gtk_window_present(existing);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  GdkVisual* rgba_visual = gdk_screen_get_rgba_visual(gtk_window_get_screen(window));
  if (rgba_visual != nullptr) {
    gtk_widget_set_visual(GTK_WIDGET(window), rgba_visual);
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Visor Config");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Visor Config");
  }

  // Resolve the icon beside the executable so unpacked bundles also use it.
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* bundle_dir = g_path_get_dirname(executable);
    g_autofree gchar* icon_path = g_build_filename(
        bundle_dir, "data", "flutter_assets", "assets", "app_icon_256.png", nullptr);
    gtk_window_set_icon_from_file(window, icon_path, nullptr);
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color = {0, 0, 0, 0};
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->launch_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "visor-config/launch", FL_METHOD_CODEC(codec));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Keep terminal-only options in the invoking process, even with a window open.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  for (char** arg = *arguments + 1; *arg != nullptr; ++arg) {
    if (g_str_equal(*arg, "--")) break;
    if (g_str_equal(*arg, "--file") || g_str_equal(*arg, "--json")) {
      if (arg[1] != nullptr) {
        ++arg;
        continue;
      }
    }
    if (g_str_has_prefix(*arg, "--")) {
      g_application_set_flags(application, static_cast<GApplicationFlags>(
          g_application_get_flags(application) | G_APPLICATION_NON_UNIQUE));
      break;
    }
  }
  return G_APPLICATION_CLASS(my_application_parent_class)
      ->local_command_line(application, arguments, exit_status);
}

static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  g_auto(GStrv) arguments = g_application_command_line_get_arguments(
      command_line, nullptr);
  if (self->launch_channel == nullptr) {
    self->dart_entrypoint_arguments = g_strdupv(arguments + 1);
    g_application_activate(application);
    return 0;
  }

  g_application_activate(application);
  if (arguments[1] == nullptr) return 0;

  g_autoptr(FlValue) request = fl_value_new_map();
  FlValue* inputs = fl_value_new_list();
  for (char** arg = arguments + 1; *arg != nullptr; ++arg) {
    fl_value_append_take(inputs, fl_value_new_string(*arg));
  }
  fl_value_set_string_take(request, "arguments", inputs);
  const char* cwd = g_application_command_line_get_cwd(command_line);
  if (cwd != nullptr) {
    fl_value_set_string_take(request, "cwd", fl_value_new_string(cwd));
  }
  if (self->first_frame_rendered) {
    fl_method_channel_invoke_method(self->launch_channel, "open", request,
                                    nullptr, nullptr, nullptr);
  } else {
    g_ptr_array_add(self->pending_launches, fl_value_ref(request));
  }
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_pointer(&self->pending_launches, g_ptr_array_unref);
  g_clear_object(&self->launch_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->pending_launches = g_ptr_array_new_with_free_func(
      reinterpret_cast<GDestroyNotify>(fl_value_unref));
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE, nullptr));
}
