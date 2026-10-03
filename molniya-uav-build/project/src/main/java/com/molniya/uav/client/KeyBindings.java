package com.molniya.uav.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.molniya.uav.MolniyaUavMod;
import net.minecraft.client.KeyMapping;
import org.lwjgl.glfw.GLFW;

public final class KeyBindings {
    public static final String CATEGORY = "key.categories." + MolniyaUavMod.MOD_ID;

    public static final KeyMapping ENGINE_TOGGLE = new KeyMapping(
            "key.molniya_uav.engine_toggle",
            InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_R,
            CATEGORY
    );

    public static final KeyMapping EXIT_CONTROL = new KeyMapping(
            "key.molniya_uav.exit_control",
            InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_F,
            CATEGORY
    );

    private KeyBindings() {}
}
