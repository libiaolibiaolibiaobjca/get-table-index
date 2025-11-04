package org.example;

import cn.hutool.core.lang.Assert;
import cn.hutool.core.lang.ConsistentHash;
import java.util.ArrayList;
import java.util.Collection;
import lombok.var;

/**
 * Hello world!
 */
public class App {

  public static final int SHARD = 1024;
  public static final ConsistentHash<Integer> consistentHash = new ConsistentHash<Integer>(2 ^ 20, getNodes());

  public static void main(String[] args) {
    final String input = args[0];
    Assert.notBlank(input, "input is blank");

    System.out.println("--------");
    System.out.println("input : " + input);
    System.out.println("--------");
    Integer idx = consistentHash.get(input);
    System.out.println(String.format("dbIndex : %d/%d, tableIndex : %d/%d", idx / 128, 128, idx, SHARD));
    System.out.println(String.format("eg. db_%d.table_%d", idx / 128, idx));
    System.out.println(String.format("eg. bedrock_oss_%d.file_%d", idx / 128, idx));
  }

  private static Collection<Integer> getNodes() {
    var list = new ArrayList<Integer>();
    for (int i = 0; i < SHARD; i++) {
      list.add(i);
    }
    return list;
  }


}
