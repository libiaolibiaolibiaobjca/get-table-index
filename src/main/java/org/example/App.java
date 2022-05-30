package org.example;

import cn.hutool.core.lang.ConsistentHash;
import java.util.ArrayList;
import java.util.Collection;
import lombok.val;
import lombok.var;

/**
 * Hello world!
 */
public class App {

  public static final int SHARD = 1024;

  public static void main(String[] args) {
    System.out.println("Hello World!");

    val consistentHash = new ConsistentHash<>(2 ^ 20, getNodes());
    System.out.println(args[0]);
    Integer hash = consistentHash.get(args[0]);
    System.out.println(hash);
  }

  private static Collection<Integer> getNodes() {
    var list = new ArrayList<Integer>();
    for (int i = 0; i < SHARD; i++) {
      list.add(i);
    }
    return list;
  }


}
