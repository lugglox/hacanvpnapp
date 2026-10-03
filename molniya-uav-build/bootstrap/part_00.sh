#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname 'build.gradle')"
cat > 'build.gradle' <<'MOLNIYA_EOF'
plugins {
    id 'eclipse'
    id 'idea'
    id 'maven-publish'
    id 'net.minecraftforge.gradle' version '[6.0,6.2)'
    id 'org.parchmentmc.librarian.forgegradle' version '1.+'
}

version = mod_version
group = mod_group_id

base {
    archivesName = mod_id
}

java.toolchain.languageVersion = JavaLanguageVersion.of(17)

minecraft {
    mappings channel: mapping_channel, version: mapping_version
    copyIdeResources = true

    runs {
        configureEach {
            workingDirectory project.file('run')
            property 'forge.logging.markers', 'REGISTRIES'
            property 'forge.logging.console.level', 'info'
            mods {
                "${mod_id}" {
                    source sourceSets.main
                }
            }
        }
        client {
            property 'forge.enabledGameTestNamespaces', mod_id
        }
        server {
            property 'forge.enabledGameTestNamespaces', mod_id
            args '--nogui'
        }
        gameTestServer {
            property 'forge.enabledGameTestNamespaces', mod_id
        }
        data {
            workingDirectory project.file('run-data')
            args '--mod', mod_id, '--all', '--output', file('src/generated/resources/'), '--existing', file('src/main/resources/')
        }
    }
}

sourceSets.main.resources { srcDir 'src/generated/resources' }

repositories {
}

dependencies {
    minecraft "net.minecraftforge:forge:${minecraft_version}-${forge_version}"
}

tasks.named('processResources', ProcessResources).configure {
    var replaceProperties = [
            minecraft_version: minecraft_version, minecraft_version_range: minecraft_version_range,
            forge_version: forge_version, forge_version_range: forge_version_range,
            loader_version_range: loader_version_range,
            mod_id: mod_id, mod_name: mod_name, mod_license: mod_license, mod_version: mod_version,
            mod_authors: mod_authors, mod_description: mod_description,
    ]
    inputs.properties replaceProperties
    filesMatching(['META-INF/mods.toml', 'pack.mcmeta']) {
        expand replaceProperties + [project: project]
    }
}

tasks.named('jar', Jar).configure {
    manifest {
        attributes([
                'Specification-Title'     : mod_id,
                'Specification-Vendor'    : mod_authors,
                'Specification-Version'   : '1',
                'Implementation-Title'    : project.name,
                'Implementation-Version'  : project.jar.archiveVersion,
                'Implementation-Vendor'   : mod_authors,
                'Implementation-Timestamp': new Date().format("yyyy-MM-dd'T'HH:mm:ssZ")
        ])
    }
    finalizedBy 'reobfJar'
}

tasks.withType(JavaCompile).configureEach {
    options.encoding = 'UTF-8'
}

MOLNIYA_EOF
mkdir -p "$(dirname 'settings.gradle')"
cat > 'settings.gradle' <<'MOLNIYA_EOF'
pluginManagement {
    repositories {
        gradlePluginPortal()
        maven {
            name = 'MinecraftForge'
            url = 'https://maven.minecraftforge.net/'
        }
        maven { url = 'https://maven.parchmentmc.org' }
    }
}

plugins {
    id 'org.gradle.toolchains.foojay-resolver-convention' version '0.7.0'
}

rootProject.name = 'Molniya-UAV'

MOLNIYA_EOF
mkdir -p "$(dirname 'gradle.properties')"
cat > 'gradle.properties' <<'MOLNIYA_EOF'
org.gradle.jvmargs=-Xmx3G
org.gradle.daemon=false

minecraft_version=1.20.1
minecraft_version_range=[1.20.1,1.21)
forge_version=47.4.10
forge_version_range=[47.4.10,48)
loader_version_range=[47,)
mapping_channel=parchment
mapping_version=2023.09.03-1.20.1

mod_id=molniya_uav
mod_name=Molniya UAV
mod_license=MIT
mod_version=1.0.0-1.20.1
mod_group_id=com.molniya.uav
mod_authors=Molniya UAV Project
mod_description=Controllable fixed-wing Molniya UAV with custom flight physics, networking, HUD and model.

MOLNIYA_EOF
mkdir -p "$(dirname 'src/main/java/com/molniya/uav/MolniyaUavMod.java')"
cat > 'src/main/java/com/molniya/uav/MolniyaUavMod.java' <<'MOLNIYA_EOF'
package com.molniya.uav;

import com.molniya.uav.network.ModNetworking;
import com.molniya.uav.registry.ModCreativeTabs;
import com.molniya.uav.registry.ModEntities;
import com.molniya.uav.registry.ModItems;
import com.molniya.uav.registry.ModSounds;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.event.lifecycle.FMLCommonSetupEvent;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(MolniyaUavMod.MOD_ID)
public final class MolniyaUavMod {
    public static final String MOD_ID = "molniya_uav";

    public MolniyaUavMod() {
        IEventBus modBus = FMLJavaModLoadingContext.get().getModEventBus();
        ModEntities.ENTITIES.register(modBus);
        ModItems.ITEMS.register(modBus);
        ModCreativeTabs.CREATIVE_TABS.register(modBus);
        ModSounds.SOUNDS.register(modBus);
        modBus.addListener(this::commonSetup);
    }

    private void commonSetup(FMLCommonSetupEvent event) {
        event.enqueueWork(ModNetworking::register);
    }
}

MOLNIYA_EOF
mkdir -p "$(dirname 'src/main/java/com/molniya/uav/client/ClientControlState.java')"
cat > 'src/main/java/com/molniya/uav/client/ClientControlState.java' <<'MOLNIYA_EOF'
package com.molniya.uav.client;

import com.molniya.uav.entity.MolniyaUavEntity;
import com.molniya.uav.network.ModNetworking;
import com.molniya.uav.network.UavControlPacket;
import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.Entity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.api.distmarker.OnlyIn;

@OnlyIn(Dist.CLIENT)
public final class ClientControlState {
    private static int controlledEntityId = -1;

    public static void start(MolniyaUavEntity uav) {
        controlledEntityId = uav.getId();
        Minecraft minecraft = Minecraft.getInstance();
        minecraft.setCameraEntity(uav);
    }

    public static void stop(boolean notifyServer) {
        Minecraft minecraft = Minecraft.getInstance();
        if (notifyServer && controlledEntityId >= 0) {
            ModNetworking.sendToServer(new UavControlPacket(controlledEntityId,
                    0.0F, 0.0F, 0.0F, false, false, true));
        }
        controlledEntityId = -1;
        if (minecraft.player != null) {
            minecraft.setCameraEntity(minecraft.player);
        }
    }

    public static boolean isControlling() {
        return getControlledUav() != null;
    }

    public static MolniyaUavEntity getControlledUav() {
        Minecraft minecraft = Minecraft.getInstance();
        if (controlledEntityId < 0 || minecraft.level == null) return null;
        Entity entity = minecraft.level.getEntity(controlledEntityId);
        if (entity instanceof MolniyaUavEntity uav && !uav.isRemoved()) {
            return uav;
        }
        if (controlledEntityId >= 0) {
            stop(false);
        }
        return null;
    }

    private ClientControlState() {}
}

MOLNIYA_EOF
mkdir -p "$(dirname 'src/main/java/com/molniya/uav/client/ClientEvents.java')"
cat > 'src/main/java/com/molniya/uav/client/ClientEvents.java' <<'MOLNIYA_EOF'
package com.molniya.uav.client;

import com.molniya.uav.MolniyaUavMod;
import com.molniya.uav.client.hud.UavHudOverlay;
import com.molniya.uav.client.model.MolniyaUavModel;
import com.molniya.uav.client.renderer.MolniyaUavRenderer;
import com.molniya.uav.client.sound.UavMotorSound;
import com.molniya.uav.entity.MolniyaUavEntity;
import com.molniya.uav.network.ModNetworking;
import com.molniya.uav.network.UavControlPacket;
import com.molniya.uav.registry.ModEntities;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.Input;
import net.minecraft.world.entity.Entity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.MovementInputUpdateEvent;
import net.minecraftforge.client.event.RegisterGuiOverlaysEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public final class ClientEvents {
    @Mod.EventBusSubscriber(modid = MolniyaUavMod.MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
    public static final class ModBusEvents {
        @SubscribeEvent
        public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
            event.registerEntityRenderer(ModEntities.MOLNIYA_UAV.get(), MolniyaUavRenderer::new);
        }

        @SubscribeEvent
        public static void registerLayers(EntityRenderersEvent.RegisterLayerDefinitions event) {
            event.registerLayerDefinition(MolniyaUavModel.LAYER_LOCATION, MolniyaUavModel::createBodyLayer);
        }

        @SubscribeEvent
        public static void registerKeys(RegisterKeyMappingsEvent event) {
            event.register(KeyBindings.ENGINE_TOGGLE);
            event.register(KeyBindings.EXIT_CONTROL);
        }

        @SubscribeEvent
        public static void registerOverlays(RegisterGuiOverlaysEvent event) {
            event.registerAboveAll("uav_hud", UavHudOverlay.INSTANCE);
        }
    }

    @Mod.EventBusSubscriber(modid = MolniyaUavMod.MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
    public static final class ForgeBusEvents {
        private static final Map<Integer, UavMotorSound> MOTOR_SOUNDS = new HashMap<>();

        @SubscribeEvent
        public static void clientTick(TickEvent.ClientTickEvent event) {
            if (event.phase != TickEvent.Phase.END) return;
            Minecraft minecraft = Minecraft.getInstance();
            if (minecraft.player == null || minecraft.level == null) return;

            tickMotorSounds(minecraft);

            MolniyaUavEntity uav = ClientControlState.getControlledUav();
            if (uav == null || minecraft.screen != null) return;

            float throttle = (minecraft.options.keyUp.isDown() ? 1.0F : 0.0F)
                    - (minecraft.options.keyDown.isDown() ? 1.0F : 0.0F);
            float yaw = (minecraft.options.keyRight.isDown() ? 1.0F : 0.0F)
                    - (minecraft.options.keyLeft.isDown() ? 1.0F : 0.0F);
            float pitch = (minecraft.options.keyJump.isDown() ? 1.0F : 0.0F)
                    - (minecraft.options.keyShift.isDown() ? 1.0F : 0.0F);

            boolean engineChange = KeyBindings.ENGINE_TOGGLE.consumeClick();
            boolean desiredEngine = engineChange ? !uav.isEngineOn() : uav.isEngineOn();

            if (KeyBindings.EXIT_CONTROL.consumeClick()) {
                ClientControlState.stop(true);
                return;
            }

            ModNetworking.sendToServer(new UavControlPacket(
                    uav.getId(), throttle, yaw, pitch, desiredEngine, engineChange, false));
        }

        @SubscribeEvent
        public static void movementInput(MovementInputUpdateEvent event) {
            if (!ClientControlState.isControlling()) return;
            Input input = event.getInput();
            input.leftImpulse = 0.0F;
            input.forwardImpulse = 0.0F;
            input.up = false;
            input.down = false;
            input.left = false;
            input.right = false;
            input.jumping = false;
            input.shiftKeyDown = false;
        }

        private static void tickMotorSounds(Minecraft minecraft) {
            Iterator<Map.Entry<Integer, UavMotorSound>> it = MOTOR_SOUNDS.entrySet().iterator();
            while (it.hasNext()) {
                Map.Entry<Integer, UavMotorSound> entry = it.next();
                if (!minecraft.getSoundManager().isActive(entry.getValue()) || entry.getValue().isStopped()) {
                    it.remove();
                }
            }

            for (Entity entity : minecraft.level.entitiesForRendering()) {
                if (entity instanceof MolniyaUavEntity uav && uav.isEngineOn()
                        && !MOTOR_SOUNDS.containsKey(uav.getId())) {
                    UavMotorSound sound = new UavMotorSound(uav);
                    MOTOR_SOUNDS.put(uav.getId(), sound);
                    minecraft.getSoundManager().play(sound);
                }
            }
        }
    }

    private ClientEvents() {}
}

MOLNIYA_EOF
mkdir -p "$(dirname 'src/main/java/com/molniya/uav/client/ClientPacketHandler.java')"
cat > 'src/main/java/com/molniya/uav/client/ClientPacketHandler.java' <<'MOLNIYA_EOF'
package com.molniya.uav.client;

import com.molniya.uav.client.screen.UavInfoScreen;
import com.molniya.uav.entity.MolniyaUavEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.Entity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.api.distmarker.OnlyIn;

@OnlyIn(Dist.CLIENT)
public final class ClientPacketHandler {
    public static void startControl(int entityId) {
        Minecraft minecraft = Minecraft.getInstance();
        if (minecraft.level == null) return;
        Entity entity = minecraft.level.getEntity(entityId);
        if (entity instanceof MolniyaUavEntity uav) {
            ClientControlState.start(uav);
        }
    }

    public static void openInfo(int entityId) {
        Minecraft minecraft = Minecraft.getInstance();
        if (minecraft.level == null) return;
        Entity entity = minecraft.level.getEntity(entityId);
        if (entity instanceof MolniyaUavEntity uav) {
            minecraft.setScreen(new UavInfoScreen(uav));
        }
    }

    private ClientPacketHandler() {}
}

MOLNIYA_EOF
